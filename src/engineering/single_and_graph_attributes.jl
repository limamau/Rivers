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

    # Get conutry
    complete_countries = grdc_ds["country"][:]

    # Get logitude and latitude
    complete_longitudes = grdc_ds["geo_x"][:]
    complete_latitudes = grdc_ds["geo_y"][:]
    
    # Get grdc IDs
    gauge_ids = grdc_ds["gauge_id"][:]

    # Selected variables arrays
    selected_areas = Vector{Float64}(undef, length(basin_ids))
    selected_countries = fill("-", length(basin_ids))
    selected_longitudes = Vector{Float64}(undef, length(basin_ids))
    selected_latitudes = Vector{Float64}(undef, length(basin_ids))

    for (i, basin_id) in enumerate(basin_ids)
        # Get gauge ID
        gauge_id = basin_gauge_dict[string(basin_id)][1]
        
        # Find its index in dataset
        grdc_idx = findfirst(id -> id == gauge_id, gauge_ids)

        # Add the area to selected areas vector
        selected_areas[i] = complete_areas[grdc_idx]

        # Add the country
        selected_countries[i] = complete_countries[grdc_idx]

        # Add longitude and latitude
        selected_longitudes[i] = complete_longitudes[grdc_idx]
        selected_latitudes[i] = complete_latitudes[grdc_idx]
    end

    # Create DataFrame
    attributes_df = DataFrame(
        basin_id = basin_ids, 
        area = selected_areas, 
        country = selected_countries,
        longitude = selected_longitudes,
        latitude = selected_latitudes)

    # Sort
    sort!(attributes_df)

    # Write csv
    CSV.write(joinpath(output_dir, "other_attributes.csv"), attributes_df)
end