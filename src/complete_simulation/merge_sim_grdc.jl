using Rivers
using CSV
using Dates
using DataFrames
using NCDatasets
using JSON
using ProgressMeter
using Shapefile

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

function merge_sim_grdc(simulations_dir::String, 
                        grdc_nc_file::String, 
                        basin_gauge_dict_file::String, 
                        graph_dict_file::String,
                        shape_file,
                        output_dir::String)
    # Get a list of all files in the simulations directory
    basin_files = readdir(simulations_dir)

    # Open the NetCDF file corresponding to the gauge ID
    grdc_ds = NCDataset(grdc_nc_file)
    gauge_ids = grdc_ds["gauge_id"][:]
    dates = grdc_ds["date"][:]
    
    # Read matching dictionary
    basin_gauge_dict = JSON.parsefile(basin_gauge_dict_file)

    # Read graph dictionary
    graph_dict = JSON.parsefile(graph_dict_file)

    # Get min and max date of the basin time series
    basin_df = CSV.read(joinpath(simulations_dir, basin_files[1]), DataFrame)
    min_date, max_date = Date(1991, 06, 23), Date(1999, 9, 30)

    # Find NetCDF corresponding index
    nc_min_date_idx = findfirst(date -> date == min_date, dates)
    nc_max_date_idx = findfirst(date -> date == max_date, dates)

    # Open the shapefile as DataFrame
    shape_df = Shapefile.Table(shape_file) |> DataFrame

    # Create output directory
    if isdir(output_dir)
        rm(output_dir, recursive=true)
    end
    mkpath(output_dir)

    msg = "Merging simulations and observations..."
    @showprogress msg for basin_file in basin_files
        basin_id = split(basename(basin_file), "_")[end][1:end-4]
        basin_df = CSV.read(joinpath(simulations_dir, basin_file), DataFrame)
        basin_df = filter(row -> min_date <= row.date <= max_date, basin_df)
    
        # Check if the basin id exists in the basin_gauge_dictionary
        if haskey(basin_gauge_dict, basin_id)
            # Get streamflow timeseries
            streamflow = get_streamflow(basin_id, basin_gauge_dict, grdc_ds, gauge_ids)
            
            # Add the streamflow values to the basin data
            basin_df[!, "obs"] = streamflow[nc_min_date_idx:nc_max_date_idx]

            # Write the merged data to a new file
            CSV.write(joinpath(output_dir, basin_file), basin_df)
        end
    end

    # Close the NetCDF file
    close(grdc_ds)
end

# Run
let
    # Base
    base = "/central/scratch/mdemoura/Rivers"
    hydro_lv = "05"
    
    # Create basin - gauge dictionary with 'grdc' criteria
    grdc_nc_file = joinpath(base, "midway_data/GRDC-Globe/grdc-merged.nc")
    shape_file = joinpath(base, "source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev$hydro_lv.shp")
    basin_gauge_dict_file = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv$hydro_lv"*"_grdc.json")
    graph_dict_file = joinpath(base, "midway_data/graph_dicts/graph_lv$hydro_lv.json")
    # gauges_to_basins(grdc_nc_file, shape_file, basin_gauge_dict_file, true, "grdc", graph_dict_file)

    # Merge simulation csvs with grdc netcdf in the gauged_simulations directory
    simulations_dir = joinpath(base, "complete_simulation/simulations/simulations_lv$hydro_lv/")
    output_dir = joinpath(base, "complete_simulation/gauged_simulations/")
    merge_sim_grdc(simulations_dir, grdc_nc_file, basin_gauge_dict_file, graph_dict_file, shape_file, output_dir)
end