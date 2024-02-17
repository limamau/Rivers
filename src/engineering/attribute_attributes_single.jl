using CSV
using DataFrames
using NCDatasets
using JSON
using Shapefile
using Statistics

include("single_and_graph_attributes.jl")

"""
    create_hydroatlas_attributes(hydroatlas_df, basins_ids, output_dir)

Creates a CSV file containing the attributes from the HydroAtlas shapefile for the specified basins.
"""
function create_hydroatlas_attributes(hydroatlas_df::DataFrame,
                                      basins_ids::Vector{Int},
                                      output_dir::String)
    # Join DataFrames
    attributes_df = hydroatlas_df[findall(in(basins_ids), hydroatlas_df.HYBAS_ID), :]

    # Rename HYBAS_ID column to basin_id
    rename!(attributes_df, :HYBAS_ID => :basin_id)

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

    # Create output directory
    mkpath(output_dir)

    # Create Hydro Atlas attributes csv
    create_hydroatlas_attributes(hydroatlas_df, basin_ids, output_dir)

    # Create ERA5 attributes csv
    create_era5_attributes(timeseries_dir, basin_files, basin_ids, output_dir)

    # Create other attributes csv
    create_other_attributes(grdc_ds, basin_ids, basin_gauge_dict, output_dir)

    # Close the netCDF file
    close(grdc_ds)
end