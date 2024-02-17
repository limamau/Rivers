using Random
using Revise

function has_at_least_one_year_data(df::DataFrame, initial_year, final_year)
    # Define dates
    start_date = Date(initial_year, 1, 1)
    end_date = Date(final_year, 12, 31)

    # Find corresponding indexes
    start_date_idx = findfirst(df[:, :date] .== start_date)
    end_date_idx  = findfirst(df[:, :date] .== end_date)

    # Check if there's at least one consecutive year of valid data
    i = start_date_idx
    for j in start_date_idx:end_date_idx
       if !isnan(df[j, :streamflow])
            if isnan(df[i, :streamflow])
                i = j
            elseif (j - i) == 365
                return true
            end
       end
       j += 1
    end
    return false
end

function split_train_test(time_split_list::Vector{Int64}, train_ratio::Float64)
    # Generate a random permutation of indices
    permuted_indices = randperm(length(time_split_list))

    # Calculate the number of elements for the train set
    train_size = round(Int, length(time_split_list) * train_ratio)

    # Extract elements for the train set using the permuted indices
    train_list = [time_split_list[i] for i in permuted_indices[1:train_size]]

    # Extract elements for the test set using the remaining permuted indices
    test_list = [time_split_list[i] for i in permuted_indices[train_size+1:end]]

    return train_list, test_list
end


"""
    extract_basin_ids(timeseries_dir::AbstractString, output_file::AbstractString)

Extracts basin IDs from files in the timeseries directory and writes them to a text file.

# Arguments
- `timeseries_dir`: The directory containing the timeseries sub-directories per level.
- `attributes_dir`: The directory containing the attributes sub-directories per level.
- `levels`: The list of levels to be included (e.g. ["05", "06", "07"]).
- `output_file`: The name of the output directory to save the .txt files.

# Output
- 6 files corresponding to the basins list to be considered in training and testing the models in USA/Globe and time/basin
configurations.
"""
function extract_basin_lists(
    timeseries_dir::String,
    attributes_dir::String,
    levels::Vector{String},
    output_dir::String,
)
    # Define list of:
    # all basins (corresponds to the Globe - time split configuration)
    globe_time_split_list = Int64[]
    # basins in the USA
    usa_time_split_list = Int64[]

    # Iterate over the given levels
    for lv in levels
        # Read attributes csv
        csv_file = joinpath(attributes_dir, "attributes_lv$lv", "other_attributes.csv")
        attributes_df = CSV.read(csv_file, DataFrame)

        # Sub-directory containing all .csv files
        timeseries_lv_dir = joinpath(timeseries_dir, "timeseries_lv$lv")

        # Get a list of all files in the timeseries directory
        basin_files = readdir(timeseries_lv_dir)

        @showprogress "Extracting lv$lv basins..." for basin_file in basin_files
            df = CSV.read(joinpath(timeseries_lv_dir, basin_file), DataFrame)
            if has_at_least_one_year_data(df, 2000, 2010)
                # Get basin ID by the file name
                basin_id = parse(Int64, split(basename(basin_file), "_")[end][1:end-4])

                # Push it to the list of global basins
                push!(globe_time_split_list, basin_id)

                # Check if it's also in the USA
                if attributes_df[attributes_df.basin_id .== basin_id, :country][1] == "US"
                    push!(usa_time_split_list, basin_id)
                end
            end
        end
    end

    mkpath(output_dir)
    println("Writing lists...")
    # Write USA - time split 
    file = open(joinpath(output_dir, "usa_time_split_list.txt"), "w")
    for basin_id in usa_time_split_list
        write(file, "$basin_id\n")
    end
    close(file)

    usa_basin_split_train_list, usa_basin_split_test_list = split_train_test(usa_time_split_list, 0.75)

    # Write USA - basin split (train set) 
    file = open(joinpath(output_dir, "usa_basin_split_train_list.txt"), "w")
    for basin_id in usa_basin_split_train_list
        write(file, "$basin_id\n")
    end
    close(file)

    # Write USA - basin split (test set) 
    file = open(joinpath(output_dir, "usa_basin_split_test_list.txt"), "w")
    for basin_id in usa_basin_split_test_list
        write(file, "$basin_id\n")
    end
    close(file) 

    # Write Globe - time split 
    file = open(joinpath(output_dir, "globe_time_split_list.txt"), "w")
    for basin_id in globe_time_split_list
        write(file, "$basin_id\n")
    end
    close(file)

    globe_basin_split_train_list, globe_basin_split_test_list = split_train_test(globe_time_split_list, 0.75)

    # Write Globe - basin split (train set) 
    file = open(joinpath(output_dir, "globe_basin_split_train_list.txt"), "w")
    for basin_id in globe_basin_split_train_list
        write(file, "$basin_id\n")
    end
    close(file)

    # Write Globe - basin split (test set) 
    file = open(joinpath(output_dir, "globe_basin_split_test_list.txt"), "w")
    for basin_id in globe_basin_split_test_list
        write(file, "$basin_id\n")
    end
    close(file)

    println("You're set!")
end
