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

    # Discar some columns
    select!(attributes_df, Not([:geometry]))

    # Rename HYBAS_ID column to basin_id
    rename!(attributes_df, :HYBAS_ID => :basin_id)

    # Sort
    sort!(attributes_df)

    # Instantiate new columns
    min_dists = zeros(length(attributes_df.basin_id))
    max_dists = zeros(length(attributes_df.basin_id))
    mean_dists = zeros(length(attributes_df.basin_id))
    
    # Get dists list
    for (i,basin_id) in enumerate(attributes_df.basin_id)
        if !isempty(graph_dict[string(basin_id)])
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
        end
    end

    # Add columns
    attributes_df[!, "min_dist"] = min_dists
    attributes_df[!, "max_dist"] = max_dists
    attributes_df[!, "mean_dist"] = mean_dists

    # Write csv
    CSV.write(joinpath(output_dir, "hydroatlas_attributes.csv"), attributes_df)
end

"""
    find_durations(idx)

Finds the durations between consecutive indices in the given vector.
"""
function find_durations(idx::Vector{Int})
    durations = []
    duration = 1
    for i in 2:length(idx)
        if idx[i] - idx[i-1] == 1
            duration += 1
        else
            push!(durations, duration)
            duration = 1
        end
    end
    push!(durations, duration)

    return durations
end

"""
    create_era5_attributes(timeseries_dir, basin_files, basin_ids, output_dir)

Creates a CSV file containing ERA5 attributes for the specified basins.
"""
function create_era5_attributes(timeseries_dir::String,
                                basin_files::Vector{String},
                                basin_ids::Vector{Int},
                                output_dir::String)

    # Get length of a DataFrame
    basin_df = CSV.read(joinpath(timeseries_dir, basin_files[1]), DataFrame)
    len = length(basin_files)
    
    # Create vectors to store attributes for each basin
    mean_precips = Vector{Float64}(undef, len)
    high_precip_freqs = Vector{Float64}(undef, len)
    low_precip_freqs = Vector{Float64}(undef, len)
    high_prec_durs = Vector{Float64}(undef, len)
    low_precip_durs = Vector{Float64}(undef, len)

    # Iterate over all the basins
    for (i, basin_file) in enumerate(basin_files)
        # Read CSV file as DataFrame
        basin_df = CSV.read(joinpath(timeseries_dir, basin_file), DataFrame)

        # Mean precipitation
        mean_precips[i] = mean(basin_df.tp_sum)

        # High precipitation frequency
        high_precip_freqs[i] = sum(basin_df.tp_sum .>= 5*mean_precips[i]) / size(basin_df, 1)

        # Low precipitation frequency (this 1mm value seems to be so arbitrary...)
        low_precip_freqs[i] = sum(basin_df.tp_sum .< 0.001) / size(basin_df, 1)

        # # High recipitation duration
        idx = findall(basin_df.tp_sum .>= 5*mean_precips[i])
        durations = find_durations(idx)
        high_prec_durs[i] = mean(durations)
        
        # Low recipitation duration
        idx = findall(basin_df.tp_sum .< 0.001)
        durations = find_durations(idx)
        low_precip_durs[i] = mean(durations)
    end

    # Create DataFrame
    attributes_df = DataFrame(basin_id = basin_ids,
                              mean_precip = mean_precips,
                              high_precip_freq = high_precip_freqs,
                              low_precip_freq = low_precip_freqs,
                              high_prec_dur = high_prec_durs,
                              low_precip_dur = low_precip_durs)

    # Sort
    sort!(attributes_df)

    # Write CSV
    CSV.write(joinpath(output_dir, "era5_attributes.csv"), attributes_df)
end

"""
    create_other_attributes(grdc_ds, basin_ids, basin_gauge_dict, output_dir)

Creates a CSV file containing other attributes (currently just area) for the specified basins.
"""

function create_other_attributes(grdc_ds::NCDataset,
                                 basin_ids::Vector{Int},
                                 basin_gauge_dict::Dict{},
                                 output_dir::String)

    # Get areas
    complete_areas = grdc_ds["area"][:]
    complete_countries = grdc_ds["country"][:]
    
    # Get grdc IDs
    gauge_ids = grdc_ds["gauge_id"][:]

    selected_areas = Vector{Float64}(undef, length(basin_ids))
    selected_countries = fill("-", length(basin_ids))

    for (i, basin_id) in enumerate(basin_ids)
        # Get gauge ID
        gauge_id = basin_gauge_dict[string(basin_id)][1]
        
        # Find its index in dataset
        grdc_idx = findfirst(id -> id == gauge_id, gauge_ids)

        # Add the area to selected areas vector
        selected_areas[i] = complete_areas[grdc_idx]

        # Add the country
        selected_countries[i] = complete_countries[grdc_idx]
    end

    # Create DataFrame
    attributes_df = DataFrame(basin_id = basin_ids, area = selected_areas, country = selected_countries)

    # Sort
    sort!(attributes_df)

    # Write csv
    CSV.write(joinpath(output_dir, "other_attributes.csv"), attributes_df)
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