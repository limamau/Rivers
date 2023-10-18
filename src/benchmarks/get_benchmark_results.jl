using CSV
using DataFrames
using JSON
using Statistics

function mask_valid(obs::Vector{Float64}, sim::Vector{Float64})::Tuple{Vector{Float64}, Vector{Float64}}
    # mask of invalid entries. NaNs in simulations can happen during validation/testing
    idx = Vector{Bool}(undef, length(sim))
    for i in eachindex(idx)
        idx[i] = !isnan(sim[i]) & !isnan(obs[i])
    end

    obs = obs[idx]
    sim = sim[idx]

    return obs, sim
end

function get_nse(obs::Vector{Float64}, sim::Vector{Float64})::Float64
    # get time series with only valid observations
    obs, sim = mask_valid(obs, sim)

    denominator = sum((obs .- mean(obs)).^2)
    numerator = sum((sim .- obs).^2)

    value = 1.0 - numerator / denominator

    return value
end

function get_kge(obs::Vector{Float64}, sim::Vector{Float64})::Union{Missing, Float64}
    # get time series with only valid observations
    obs, sim = mask_valid(obs, sim)
    
    if isempty(obs) | isempty(sim)
        return missing
    else
        alpha = std(sim) / std(sim)
        beta = mean(sim) / mean(sim)
        r = cor(sim, obs)

        return 1 - sqrt((alpha-1)^2 + (beta-1)^2 + (r-1)^2)
    end
end

let
    # Read base csv file as DataFrame
    base_csv = "article/csv_files/globe_all_daily.csv"
    base_df = CSV.read(base_csv, DataFrame)

    # Get gauges list
    basin_gauge_dict_lv05 = JSON.parsefile("/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/gauge_to_basin_dict_lv05_max.json")
    basin_gauge_dict_lv06 = JSON.parsefile("/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/gauge_to_basin_dict_lv06_max.json")
    basin_gauge_dict_lv07 = JSON.parsefile("/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/gauge_to_basin_dict_lv07_max.json")

    # Get GloFAS upstreams areas
    gauge_area_dict = JSON.parsefile("/central/scratch/mdemoura/Rivers/midway_data/era5/gauge_area_dict.json")

    # Merge mapping dictionaries
    mapping_dict = merge(basin_gauge_dict_lv05, basin_gauge_dict_lv06, basin_gauge_dict_lv07)

    # Define basins to calculate scores
    basins = base_df.basin

    for model in ["glofas"] # , "pcr"]
        # Define array to allocate scores
        nses = []
        kges = []
        selected_basins = []
        up_areas = []

        # Define directory
        if model == "glofas"
            base_dir = "/central/scratch/mdemoura/Rivers/post_data/glofas_timeseries"
        else
            base_dir = "/central/scratch/mdemoura/Rivers/post_data/pcr_timeseries_old"
        end

        for i in eachindex(basins)
            basin_id = basins[i]
            gauge_id = mapping_dict[string(basin_id)][1]
            file = joinpath(base_dir, "sim_$basin_id.csv")

            # Get timeseries as Data Frame if the file exists
            if isfile(file)
                df = CSV.read(file, DataFrame)

                # Define observation and simulation series from DataFrame
                obs = replace(df[:,2], missing => NaN)
                sim = replace(df[:,3], missing => NaN)

                # Get scores
                push!(nses, get_nse(obs, sim))
                push!(kges, get_kge(obs, sim))
                push!(selected_basins, basins[i])
            end
        end

        # Choose not NaN and not Inf values
        idx = Vector{Bool}(undef, length(nses))
        for i in eachindex(nses)
            idx[i] = !isnan(nses[i]) & !isinf(nses[i]) & !isnan(kges[i])
        end

        # Check
        for i in eachindex(nses)
            if nses[i] > 1
                error("NSE > 1 at index $i.")
            end
        end

        # Write results
        if model == "pcr"
            CSV.write("article/csv_files/pcr_monthly.csv", DataFrame(basin=selected_basins[idx], nse=nses[idx], kge=kges[idx]))
        elseif model == "glofas"
            CSV.write("article/csv_files/glofas_daily.csv", DataFrame(basin=selected_basins[idx], 
                                                                      nse=nses[idx], 
                                                                      kge=kges[idx]))
        end
    end
end
