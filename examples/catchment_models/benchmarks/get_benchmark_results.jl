using CSV
using DataFrames
using JSON
using Statistics

include("utils.jl")

function main()
    # Base
    base = "/users/mlima/data_for_revisions"
    analysis_dir = normpath(joinpath(@__DIR__, "../analysis"))

    # Read base csv file as DataFrame
    base_csv = "examples/catchment_models/analysis/csv_files/globe_all_daily.csv"
    base_df = CSV.read(base_csv, DataFrame)

    # Get gauges list
    basin_gauge_dict_lv05 = JSON.parsefile(joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv05_max.json"))
    basin_gauge_dict_lv06 = JSON.parsefile(joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv06_max.json"))
    basin_gauge_dict_lv07 = JSON.parsefile(joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv07_max.json"))

    # Merge mapping dictionaries
    mapping_dict = merge(basin_gauge_dict_lv05, basin_gauge_dict_lv06, basin_gauge_dict_lv07)
    
    # Get GloFAS upstreams areas
    gauge_area_dict = JSON.parsefile(joinpath(base, "midway_data/era5/gauge_area_dict.json"))

    other_attributes_lv05_df = CSV.read(joinpath(base, "single_model_data/attributes/attributes_lv05/other_attributes.csv"), DataFrame)
    other_attributes_lv06_df = CSV.read(joinpath(base, "single_model_data/attributes/attributes_lv06/other_attributes.csv"), DataFrame)
    other_attributes_lv07_df = CSV.read(joinpath(base, "single_model_data/attributes/attributes_lv07/other_attributes.csv"), DataFrame)
    other_attributes_df = vcat(other_attributes_lv05_df, other_attributes_lv06_df, other_attributes_lv07_df)

    # Define basins to calculate scores
    basins = base_df.basin

    # Basins used in all simulations (from LSTM, and GloFAS)
    selected_basins = []

    for model in ["glofas"]
        nses = []
        kges = []
        model_dir = joinpath(base, "post_data/$model"*"_timeseries")

        for i in eachindex(basins)
            basin_id = basins[i]
            gauge_id = mapping_dict[string(basin_id)][1]
            file = joinpath(model_dir, "basin_$basin_id.csv")

            # Get timeseries as Data Frame if the file exists
            if isfile(file)
                # Confirm areas are the same
                lstm_area = other_attributes_df[other_attributes_df.basin_id .== basin_id, :area][1]
                if haskey(gauge_area_dict, string(gauge_id))
                    glofas_area = gauge_area_dict[string(gauge_id)]
                    if !is_area_within_threshold(lstm_area, glofas_area)
                        continue
                    end
                end

                # Get DataFrame
                df = CSV.read(file, DataFrame)

                # Define observation and simulation series from DataFrame
                obs = replace(df[:,2], missing => NaN)
                sim = replace(df[:,3], missing => NaN)

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
        mkpath(joinpath(analysis_dir, "csv_files"))
        CSV.write(
            joinpath(analysis_dir, "csv_files/$model"*"_daily.csv"), 
            DataFrame(basin=selected_basins[idx], nse=nses[idx], kge=kges[idx])
        )
    end

    # Write selected basins in analysis/ folder
    selected_basins_file = open(joinpath(analysis_dir, "selected_basins.txt"), "w")
    for basin_id in selected_basins
        write(selected_basins_file, "$basin_id\n")
    end
    close(selected_basins_file)
end


if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
