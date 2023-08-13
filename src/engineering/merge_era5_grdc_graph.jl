using CSV
using DataFrames
using NCDatasets
using JSON
using ProgressMeter

function is_valid(basin_id::AbstractString, graph_dict::Dict, basin_gauge_dict::Dict)
    if !haskey(basin_gauge_dict, basin_id)
        return false
    elseif !isempty(graph_dict[basin_id])
        for up_basin in graph_dict[basin_id]
            if !haskey(basin_gauge_dict, string(up_basin))
                return false
            end
        end
    end
    return true
end

function get_streamflow(basin_id::AbstractString, basin_gauge_dict::Dict, grdc_ds::NCDataset, gauge_ids::Vector{Int32})::Vector{<:Real}
    # Get gauge id to the corresponding basin
    gauge_id = basin_gauge_dict[basin_id][1]

    # Find its index in dataset
    gauge_idx = findfirst(id -> id == gauge_id, gauge_ids)

    # Extract the streamflow variable for the gauge id
    streamflows = grdc_ds["streamflow"][gauge_idx, :]

    # Poorly handle missing values
    return replace(streamflows, missing => NaN)
end

"""
    merge_era5_grdc(timeseries_dir, grdc_nc_file, basin_gauge_dict_file, graph_dict_file, shape_file, output_dir)

Merges ERA5 timeseries data for each basin defined by HydroSHEDS with the corresponding GRDC gauge streamflow series.

# Arguments
- `timeseries_dir::String`: directory path containing the ERA5 timeseries data files for each basin.
- `grdc_nc_file::String`: path to the NetCDF file containing the GRDC gauge data.
- `basin_gauge_dict_file::String`: path to the JSON file containing the mapping between basin IDs and corresponding GRDC gauge IDs.
- `graph_dict_file::String`: path to the JSON file containing the graph dictionary.
- `shape_file:::String`: path to the HydroSHEDS shapefile.
- `output_dir::String`: directory path where the merged data files will be saved.

# Output
- One CSV file ber basin in the `output_dir`.
- Recomended for the `output_dir` to be of the kind **"path/to/timeseries/timeseries_lvXX"** for a good communication with the model
(where XX is the level in HydroSHEDS).
"""
function merge_era5_grdc(timeseries_dir::String, 
                         grdc_nc_file::String, 
                         basin_gauge_dict_file::String, 
                         graph_dict_file::String,
                         shape_file,
                         output_dir::String)
    # Get a list of all files in the timeseries directory
    basin_files = readdir(timeseries_dir)

    # Open the NetCDF file corresponding to the gauge ID
    grdc_ds = NCDataset(grdc_nc_file)
    gauge_ids = grdc_ds["gauge_id"][:]
    dates = grdc_ds["date"][:]
    
    # Read matching dictionary
    basin_gauge_dict = JSON.parsefile(basin_gauge_dict_file)

    # Read graph
    graph_dict = JSON.parsefile(graph_dict_file)

    # Get min and max date of the basin time series
    basin_df = CSV.read(joinpath(timeseries_dir, basin_files[1]), DataFrame)
    min_date, max_date = basin_df.date[1], basin_df.date[end]

    # Find NetCDF corresponding index
    min_date_idx = findfirst(date -> date == min_date, dates)
    max_date_idx = findfirst(date -> date == max_date, dates)

    # Open the shapefile
    shape_df = Shapefile.Table(shape_file) |> DataFrame

    # Create output directory
    mkdir(output_dir)

    msg = "Merging basins dynamical inputs and streamflow series..."
    @showprogress msg for basin_file in basin_files
        basin_id = split(basename(basin_file), "_")[end][1:end-4]
        basin_df = CSV.read(joinpath(timeseries_dir, basin_file), DataFrame)
    
        # Check if the basin id exists in the basin_gauge_dictionary
        if is_valid(basin_id, graph_dict, basin_gauge_dict)
            # Get streamflow timeseries
            streamflow = get_streamflow(basin_id, basin_gauge_dict, grdc_ds, gauge_ids)
            
            # Add the streamflow values to the basin data
            basin_df[!, "streamflow"] = streamflow[min_date_idx:max_date_idx]

            # Add upstream (sum and pond)
            down_dist = shape_df[shape_df.HYBAS_ID .== parse(Int, basin_id), :DIST_MAIN][1]
            pond_upstream = zeros(max_date_idx-min_date_idx+1)
            upstream = zeros(max_date_idx-min_date_idx+1)
            dist_sum = 0
            if !isempty(graph_dict[basin_id])
                for up_basin in graph_dict[basin_id]
                    up_dist = shape_df[shape_df.HYBAS_ID .== up_basin, :DIST_MAIN][1]
                    dist = down_dist - up_dist
                    streamflow = get_streamflow(string(up_basin), basin_gauge_dict, grdc_ds, gauge_ids)[min_date_idx:max_date_idx]
                    upstream += streamflow
                    pond_upstream += streamflow * dist
                    dist_sum += dist
                end
                pond_upstream = pond_upstream / dist_sum
            end
            basin_df[!, "upstream"] = upstream
            basin_df[!, "pond_upstream"] = pond_upstream

            # Write the merged data to a new file
            CSV.write(joinpath(output_dir, basin_file), basin_df)
        end
    end

    # Close the NetCDF file
    close(grdc_ds)
end