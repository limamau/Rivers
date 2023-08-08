using CSV
using DataFrames
using NCDatasets
using JSON
using ProgressMeter

"""
    merge_era5_grdc(timeseries_dir, grdc_nc_file, basin_gauge_dict_file, output_dir)
Merges ERA5 timeseries data for each basin defined by HydroSHEDS with the corresponding GRDC gauge streamflow series.
# Arguments
- `timeseries_dir::String`: directory path containing the ERA5 timeseries data files for each basin.
- `grdc_nc_file::String`: path to the NetCDF file containing the GRDC gauge data.
- `basin_gauge_dict_file::String`: path to the JSON file containing the mapping between basin IDs and corresponding GRDC gauge IDs.
- `output_dir::String`: directory path where the merged data files will be saved.
# Output
- One CSV file ber basin in the `output_dir`.
- Recomended for the `output_dir` to be of the kind **"path/to/timeseries/timeseries_lvXX"** for a good communication with the model
(where XX is the level in HydroSHEDS).
"""
function merge_era5_grdc(timeseries_dir::String, grdc_nc_file::String, basin_gauge_dict_file::String, output_dir::String)
    # Get a list of all files in the timeseries directory
    basin_files = readdir(timeseries_dir)

    # Open the NetCDF file corresponding to the gauge ID
    grdc_ds = NCDataset(grdc_nc_file)
    gauge_ids = grdc_ds["gauge_id"][:]
    dates = grdc_ds["date"][:]

    # Read matching dictionary
    basin_gauge_dict = JSON.parsefile(basin_gauge_dict_file)

    # Get min and max date of the basin time series
    basin_df = CSV.read(joinpath(timeseries_dir, basin_files[1]), DataFrame)
    min_date, max_date = basin_df.date[1], basin_df.date[end]

    # Find NetCDF corresponding index
    min_date_idx = findfirst(date -> date == min_date, dates)
    max_date_idx = findfirst(date -> date == max_date, dates)

    # Create output directory
    mkpath(output_dir)

    msg = "Merging basins dynamical inputs and streamflow series..."
    @showprogress msg for basin_file in basin_files
        basin_id = split(basename(basin_file), "_")[end][1:end-4]
        basin_df = CSV.read(joinpath(timeseries_dir, basin_file), DataFrame)

        # Check if the basin id exists in the basin_gauge_dictionary
        if haskey(basin_gauge_dict, basin_id)
            # Get gauge id to the corresponding basin
            gauge_id = basin_gauge_dict[basin_id][1]

            # Find its index in dataset
            gauge_idx = findfirst(id -> id == gauge_id, gauge_ids)

            # Extract the streamflow variable for the gauge id
            streamflows = grdc_ds["streamflow"][gauge_idx, :]

            # Poorly handle missing values
            streamflows_with_NaN = replace(streamflows, missing => NaN)

            # Add the streamflow values to the basin data
            basin_df[!, "streamflow"] = streamflows_with_NaN[min_date_idx:max_date_idx]

            # Write the merged data to a new file
            CSV.write(joinpath(output_dir, basin_file), basin_df)
        end
    end

    # Close the NetCDF file
    close(grdc_ds)
end