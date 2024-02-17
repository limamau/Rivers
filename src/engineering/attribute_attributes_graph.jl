using CSV
using DataFrames
using NCDatasets
using JSON
using Shapefile
using Statistics

"""
    create_hydroatlas_attributes(hydroatlas_df, basins_ids, graph_dict, output_dir)

Creates a CSV file containing the attributes from the HydroAtlas shapefile for the specified basins.
"""
function create_hydroatlas_attributes(hydroatlas_df::DataFrame,
                                      basins_ids::Vector{Int},
                                      graph_dict::Dict,
                                      output_dir::String)
    # Join DataFrames
    attributes_df = hydroatlas_df[findall(in(basins_ids), hydroatlas_df.HYBAS_ID), :]

    # Rename HYBAS_ID column to basin_id
    rename!(attributes_df, :HYBAS_ID => :basin_id)

    # Instantiate new columns
    min_dists = zeros(length(attributes_df.basin_id))
    max_dists = zeros(length(attributes_df.basin_id))
    mean_dists = zeros(length(attributes_df.basin_id))
    max_sides = zeros(length(attributes_df.basin_id))
    is_routings = zeros(length(attributes_df.basin_id))
    
    # Get dists list
    for (i,basin_id) in enumerate(attributes_df.basin_id)
        is_routing = 0
        if !isempty(graph_dict[string(basin_id)])
            is_routing = 1
            dists = []
            down_dist = hydroatlas_df[hydroatlas_df.HYBAS_ID .== basin_id, :DIST_MAIN][1]
            for up_basin in graph_dict[string(basin_id)]
                up_dist = hydroatlas_df[hydroatlas_df.HYBAS_ID .== up_basin, :DIST_MAIN][1]
                dist = down_dist - up_dist
                push!(dists, dist)
            end
            min_dists[i] = minimum(dists)
            max_dists[i] = maximum(dists)
            mean_dists[i] = mean(dists)
            is_routings[i] = is_routing
        end
        min_lon, max_lon, min_lat, max_lat = find_min_max_lon_lat(hydroatlas_df[hydroatlas_df.HYBAS_ID .== basin_id, :geometry][1].points, 0.0)
        max_sides[i] = max(max_lon-min_lon, max_lat-min_lat)
    end

    # Add columns
    attributes_df[!, "min_dist"] = min_dists
    attributes_df[!, "max_dist"] = max_dists
    attributes_df[!, "mean_dist"] = mean_dists
    attributes_df[!, "max_side"] = max_sides
    attributes_df[!, "is_routing"] = is_routings

    # Discard geomtry column
    select!(attributes_df, Not([:geometry]))

    # Sort
    sort!(attributes_df)

    # Write csv
    CSV.write(joinpath(output_dir, "hydroatlas_attributes.csv"), attributes_df)
end

"""
    attribute_attributes(hydroatlas_shapefile, timeseries_dir, grdc_ncfile, basin_gauge_dict_file, output_dir)

This function attributes the target attributes in CSV files to each basin for a given level.

# Arguments
- `hydroatlas_shapefile`: path to the HydroAtlas shapefile.
- `timeseries_dir`: directory path containing the ERA5 timeseries data files for each basin.
- `grdc_ncfile`: path to the GRDC NetCDF file.
- `basin_gauge_dict_file`: path to the JSON file containing the mapping between basin IDs and corresponding GRDC gauge IDs.
- `graph_dict_file::String`: path to the JSON file containing the graph dictionary.
- `output_dir`: directory path where the output CSV files will be saved.

# Output
- Three files ("hydroatlas_attributes.csv", "era5_attributes.csv" and "other_attributes.csv") will be created inside `output_dir`.
- Recomended for the `output_dir` to be of the kind **"path/to/attributes/attributes_lvXX"** for a good communication with the model
(where XX is the level in HydroSHEDS).
"""
function attribute_attributes(hydroatlas_shapefile::String, 
                              timeseries_dir::String, 
                              grdc_ncfile::String, 
                              basin_gauge_dict_file::String,
                              graph_dict_file::String,
                              output_dir::String)
    # Read Hydro Atlas shapefile
    hydroatlas_df = Shapefile.Table(hydroatlas_shapefile) |> DataFrame

    # Get a list of all files in the timeseries directory
    basin_files = readdir(timeseries_dir)

    # Get each basin ID by the file name
    basin_ids = [parse(Int64, split(basename(basin_file), "_")[end][1:end-4]) for basin_file in basin_files]

    # Read GRDC NetCDF file
    grdc_ds = NCDataset(grdc_ncfile)

    # Read matching dictionary
    basin_gauge_dict = JSON.parsefile(basin_gauge_dict_file)

    # Read graph dictionary
    graph_dict = JSON.parsefile(graph_dict_file)

    # Create output directory
    mkpath(output_dir)

    # Create Hydro Atlas attributes csv
    create_hydroatlas_attributes(hydroatlas_df, basin_ids, graph_dict, output_dir)

    # Create ERA5 attributes csv
    create_era5_attributes(timeseries_dir, basin_files, basin_ids, output_dir)

    # Create other attributes csv
    create_other_attributes(grdc_ds, basin_ids, basin_gauge_dict, output_dir)

    # Close the netCDF file
    close(grdc_ds)
end