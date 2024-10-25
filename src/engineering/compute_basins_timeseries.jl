using Distributed
using CSV, DataFrames, Dates, JSON, NCDatasets, ProgressMeter, Statistics

@everywhere """
    compute_basins_year_month(grid_to_basins_dir, ncfile, variables_operations_dict_file output_dir, year, month)

This function computes the time series of all given variables for all the basins over a month of a year and stores the results
in the given output directory.
"""
function compute_basins_year_month(grid_to_basins_dir::String, 
                                   ncfile::String, 
                                   variables_operations_dict_file::String, 
                                   output_dir::String,
                                   year::Int16,
                                   month::Int16)
    # Open the netCDF file
    nc = NCDataset(ncfile, "r")

    # Store dimensions
    lon_dim = nc.dim["longitude"]
    lat_dim = nc.dim["latitude"]
    time_dim = Int(nc.dim["time"])

    # Get the variables in the netCDF file to perform the operations
    variables_operations_dict = JSON.parsefile(variables_operations_dict_file)

    # Reshape the index list
    linear = LinearIndices((1:lon_dim, 1:lat_dim))

    # Read directory with dictionaries
    grid_to_basins_dict_files = readdir(grid_to_basins_dir, join=true)
    
    # Iterate over each dictionary
    for grid_to_basins_dict_file in grid_to_basins_dict_files
        # Read dictionnary from JSON file
        grid_to_basins_dict = JSON.parsefile(grid_to_basins_dict_file)

        # Pre-create all the csv files with the date column
        for (basin_id, _) in grid_to_basins_dict
            # Create a new csv file for the basin with all the dates of the year
            output_file = joinpath(output_dir, "basin_$(basin_id).csv")
            
            # Shift according to ECWMF definition of the aggregation
            start_date = Date(year, month, 1) - Day(1) 
            end_date = Date(year, month, time_dim) - Day(1)
            dates = collect(start_date:Day(1):end_date)
            CSV.write(output_file, DataFrame(date=dates))
        end

        # Iterate over all the variables to compute operation
        for (i, (var, operation)) in enumerate(variables_operations_dict)
            # Reshape the original 3D array in 2D
            # print("Reshaping variable ", var, "... [", i, "/", length(variables_operations_dict), "] -")
            rsh_arr = reshape(nc[var][:,:,:], (lon_dim*lat_dim, time_dim))
            # println(" Done!")
            
            # Iterate over each basin
            # print("Computing ", var, " for all the basins... [", i, "/", length(variables_operations_dict), "] -")
            for (basin_id, index_list) in grid_to_basins_dict
                # Create a new netCDF file for the basin
                output_file = joinpath(output_dir, "basin_$(basin_id).csv")
                output_df = CSV.read(output_file, DataFrame)
            
                # Linearize index_list
                linear_index_list = [(linear[lon_i, lat_i], proba) for (lon_i, lat_i, proba) in index_list]
                
                # Perform operation
                if operation == "sum"
                    # Get the sum of the variable over the basin indices
                    # Get the sum of probabilities
                    var_operation = zeros(time_dim)
                    sum_proba = 0
                    for (i, proba) in linear_index_list
                        if !any(ismissing, rsh_arr[i, :])
                            var_operation += rsh_arr[i, :]*proba
                            sum_proba += proba
                        end
                    end
                    # Normalize the operation
                    var_operation /= sum_proba

                elseif operation == "mean"
                    # Get the mean of the variable over the basin indices
                    var_operation = zeros(time_dim)
                    count = 0
                    for (i, proba) in linear_index_list
                        if !any(ismissing, rsh_arr[i, :])
                            var_operation += rsh_arr[i, :]*proba
                            count += 1
                        end
                    end
                    if count != 0
                        var_operation /= count
                    end
                
                else
                    error("Not supported operation in variables operations dictionnary.")
                end

                # Name of the new column
                new_column_name = string(var, "_", operation)

                # Add a new column to the DataFrame with the specified name
                output_df[!, new_column_name] = var_operation

                # Write the updated DataFrame back to the CSV file
                CSV.write(output_file, output_df)
            end
            # println(" Done!")
        end
    end

    # Close netCDF file
    close(nc)
end

@everywhere """
    get_year_and_month(nc_file)

Get the year and the month corresponding to the given NetCDF file.
The file has to be in the format "era5_YYYY_MM.nc".
"""
function get_year_and_month(nc_file::String)
    # Check if the filename has the correct format
    if occursin("era5_", nc_file) && occursin(".nc", nc_file)
        # Extract year and month as strings
        parts = split(nc_file, "_")
        if length(parts) == 3
            year_str = parts[2]
            month_str = parts[3][1:2]

            # Convert the strings to integers
            year = parse(Int16, year_str)
            month = parse(Int16, month_str)
        else
            error("Invalid nc_file format.")
        end
    else
        error("Invalid nc_file format.")
    end

    return year, month
end

"""
    merge_temp_output(temp_dir, output_dir)

Merge timeseries in the output directory and temporary directory.
"""
function merge_temp_output(temp_dir::String, output_dir::String)
    # Get a list of all files in the directory
    csvfiles = readdir(temp_dir)
    # Iterate over each of them
    for csvfile in csvfiles
        # Concatenate old output file and temporary file
        output_df = CSV.read(joinpath(output_dir, csvfile), DataFrame)
        temp_df = CSV.read(joinpath(temp_dir, csvfile), DataFrame)
        output_df = vcat(output_df, temp_df)
        
        # Write the updated DataFrame back to the CSV file
        CSV.write(joinpath(output_dir, csvfile), output_df)
    end
    # Remove temporary directory
    rm(temp_dir; recursive=true)
end

"""
    merge_temporary_directories(amount_of_files, output_dir)
Merge all temporary directories into the output directory.
"""
function merge_temporary_directories(amount_of_files::Int, output_dir::String, continue_merge::Bool)
    if !continue_merge
        # Create base DataFrame
        temp_dir = joinpath(output_dir, "temps", "temp" * lpad(1,4,"0"))
        csvfiles = readdir(temp_dir)
        column_names = names(CSV.read(joinpath(temp_dir, csvfiles[1]), DataFrame))
        df = DataFrame()
        for column_name in column_names
            df[!, Symbol(column_name)] = String[]
        end

        # Assign the created DataFrame to each file in the output directory
        for csvfile in csvfiles
            CSV.write(joinpath(output_dir, csvfile), df)
        end
    end

    msg = "Merging temporary directories..."
    @showprogress msg for i in 1:amount_of_files
        temp_dir = joinpath(output_dir, "temps", "temp" * lpad(i,4,"0"))
        if isdir(temp_dir)
            merge_temp_output(temp_dir, output_dir)
        end
    end
end

"""
    compute_basins_timeseries(grid_to_basins_dir, nc_dir, variables_operations_dict_file, output_dir)

This function computes the time series for all basins based on the given inputs. It uses parallelization (`pmap`) to speed up
the process calling a wrapper for `compute_basins_year_month()`.

# Arguments:
- `grid_to_basins_dir::String`: path to the JSON directory containing the dictionaries (JSON files) mapping basins to grid points.
The JSON must be in the format `{"basin_id":[[lon_idx,lat_idx,proba],...],...}`. It should be computed by `grid_points_to_basins()` 
or other custom function.
- `nc_dir::String`: path to the directory containing the NetCDF files. The files need to be in the format **"era5_YYYY_MM.nc"**.
- `variables_operations_dict_file::String`: path to the JSON file containing the dictionary mapping variables to operations.
The JSON must be in the format `{"var":"operation",...}` where `var` is a variable in the ERA5 netCDF files and `operation` can be
**"sum"** or **"mean"** operations.
- `output_dir::String`: path to the output directory where the computed time series will be stored.
- `checkpoint::Int`: if provided, starts computing the time series from folder temp{checkpoint}. Standard is 1 (no checkpoint).
- `continue_merge::Bool`: if true, goes directly to the merging part of the code. Standard is false (runs all the code).
# Output:
- Saves a CSV file for every basin inside `output_dir`.
"""
function compute_basins_timeseries(grid_to_basins_dir::String, 
                                   nc_dir::String, 
                                   variables_operations_dict_file::String,
                                   output_dir::String,
                                   checkpoint=1::Int,
                                   continue_merge=false::Bool)
    nc_files = readdir(nc_dir)

    # Wrapper function 
    function compute_basins_year_month_wrapper(i)
        # Get year and month of the corresponding NetCDF file
        year, month = get_year_and_month(nc_files[i])

        # Create temp directory
        temp_dir = joinpath(output_dir, "temps" , "temp" * lpad(i,4,"0"))
        mkdir(temp_dir)
        compute_basins_year_month(grid_to_basins_dir, joinpath(nc_dir, nc_files[i]), variables_operations_dict_file, temp_dir, year, month)
    end

    if !continue_merge
        # Create temporary directory
        mkpath(joinpath(output_dir, "temps"))
        
        # Compute basins time series following the parallelization scheme
        msg = "Computing temporary directories..."
        @showprogress msg pmap(compute_basins_year_month_wrapper, checkpoint:1:length(nc_files))
    end

    # Merge all temporary directories
    merge_temporary_directories(length(nc_files), output_dir, continue_merge)

    # Remove the temporary directory
    rm(joinpath(output_dir, "temps"))
end