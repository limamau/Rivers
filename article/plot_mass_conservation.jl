using CairoMakie
using CSV
using DataFrames
using Dates
using JSON
using ProgressMeter
using Statistics

function sum_positives(arr)
    # Use a vectorized operation to create an array of positive values
    positive_values = filter(x -> x > 0, arr)

    # Use the built-in `sum` function to calculate the sum of positive values
    positive_sum = sum(positive_values)

    return positive_sum
end

let
    # LSTM model
    data_dir = "/central/scratch/mdemoura/data"
    lstm_sim_dir = "/central/scratch/mdemoura/data/lstm_simulations"
    glofas_sim_dir = "/central/scratch/mdemoura/data/era5/glofas_timeseries"

    # variables to catch and plot off things
    obs_diffs = []
    obs_outliers = 0
    lstm_diffs = []
    lstm_outliers = 0
    grdc_glofas_diffs = []
    grdc_glofas_outliers = 0
    glofas_glofas_diffs::Vector{Float64} = Float64[]
    glofas_glofas_outliers = 0
    area_diffs::Vector{Float64} = Float64[]
    area_outliers = 0
    area_sizes::Vector{Float64} = Float64[]
    off_basins::Vector{Int64} = Int64[]
    off_relative_diff::Vector{Float64} = Float64[]
    off_areas_glofas::Vector{Float64} = Float64[]
    off_areas_grdc::Vector{Float64} = Float64[]

    # Read JSON with upstream areas fomr GloFAS
    gauge_area_dict = JSON.parsefile("/central/scratch/mdemoura/data/era5/gauge_area_dict.json")
    
    files = readdir(lstm_sim_dir)
    @showprogress for file in files
        # Read basin id
        basin_id = parse(Int, split(split(file, "_")[end], ".")[1])

        # Read timeseries and simulations Data Frames
        lv = string(basin_id)[2:3]
        timeseries_df = CSV.read(joinpath(data_dir, "timeseries/timeseries_lv$lv/basin_$basin_id.csv"), DataFrame)
        other_attributes_df = CSV.read(joinpath(data_dir, "attributes/attributes_lv$lv/other_attributes.csv"), DataFrame)
        hydro_attributes_df = CSV.read(joinpath(data_dir, "attributes/attributes_lv$lv/hydroatlas_attributes.csv"), DataFrame)
        lstm_sim_df = CSV.read(joinpath(lstm_sim_dir, "sim_$basin_id.csv"), DataFrame)

        # Select timeseries date indexes
        ts_min_date_idx = findfirst(date -> date == Date(1991, 01, 01), timeseries_df[:, "date"])
        ts_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), timeseries_df[:, "date"])

        # Select simulations date indexes
        sim_min_date_idx = findfirst(date -> date == Date(1991, 01, 01), lstm_sim_df[:, "date"])
        sim_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), lstm_sim_df[:, "date"])

        # Basin / catchment area
        catchment_area = other_attributes_df[other_attributes_df[:, :basin_id] .== basin_id, "area"][1]
        basin_area = hydro_attributes_df[hydro_attributes_df[:, :basin_id] .== basin_id, "UP_AREA"][1]

        # Get the sum of variables on time
        grdc_runoff = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "sro_sum"] .+ timeseries_df[ts_min_date_idx:ts_max_date_idx, "ssro_sum"]) * basin_area * 1000000
        obs_streamflow = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "streamflow"]) * 24*60*60
        lstm_streamflow = sum(lstm_sim_df[sim_min_date_idx:sim_max_date_idx, "sim"]) * 24*60*60

        # Read basin gauge dictionary and perform same operations if file exists
        basin_gauge_dict = JSON.parsefile(joinpath(data_dir, "mapping_dicts/gauge_to_basin_dict_lv$lv"*"_max.json"))
        gauge_id = basin_gauge_dict[string(basin_id)][1]
        gauge_file = joinpath(glofas_sim_dir, "gauge_$gauge_id.csv")
        if isfile(gauge_file)
            glofas_sim_df = CSV.read(gauge_file, DataFrame)
            glo_min_date_idx = findfirst(date -> date == Date(1991, 01, 01), glofas_sim_df[:, "date"])
            glo_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), glofas_sim_df[:, "date"])
            glofas_streamflow = sum(glofas_sim_df[glo_min_date_idx:glo_max_date_idx, "glofas_streamflow"]) * 24*60*60
            glofas_runoff = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "sro_sum"] .+ timeseries_df[ts_min_date_idx:ts_max_date_idx, "ssro_sum"]) * gauge_area_dict[string(gauge_id)]
        end

        # Push into arrays
        if !isnan(grdc_runoff)
            if !isnan(obs_streamflow)
                relative_diff = (obs_streamflow - grdc_runoff) / obs_streamflow
                if abs(relative_diff) < 5
                    push!(obs_diffs, relative_diff)
                else
                    obs_outliers += 1
                end
            end
            if !isnan(lstm_streamflow)
                relative_diff = (lstm_streamflow - grdc_runoff) / lstm_streamflow
                if abs(relative_diff) < 5
                    push!(lstm_diffs, relative_diff)
                else
                    lstm_outliers += 1
                end
            end
            if isfile(gauge_file)
                if !isnan(glofas_streamflow) & (glofas_streamflow != 0)
                    relative_diff = (glofas_streamflow - grdc_runoff) / glofas_streamflow
                    if abs(relative_diff) < 5
                        push!(grdc_glofas_diffs, relative_diff)
                    else
                        grdc_glofas_outliers += 1
                    end

                    relative_diff = (glofas_streamflow - glofas_runoff) / glofas_streamflow
                    if (abs(relative_diff) < 5)
                        push!(glofas_glofas_diffs, relative_diff)
                        push!(area_sizes, gauge_area_dict[string(gauge_id)])
                    else
                        glofas_glofas_outliers += 1
                    end

                    # Add to off_basins if relative difference is positive
                    if basin_id == 8070332000
                        println("Basin detected")
                        println(glofas_streamflow)
                    end
                    if relative_diff > 0
                        push!(off_basins, basin_id)
                        push!(off_relative_diff, relative_diff)
                        push!(off_areas_glofas, gauge_area_dict[string(gauge_id)])
                        push!(off_areas_grdc, catchment_area)
                    end
                end

                # Area histogram
                relative_diff = (gauge_area_dict[string(gauge_id)] - 1000000*catchment_area) / gauge_area_dict[string(gauge_id)]
                if abs(relative_diff) < 2
                    push!(area_diffs, relative_diff)
                else
                    area_outliers += 1
                end
            end
        end
    end

    # Plot histograms
    # Observation runoff diff
    fig = Figure()
    ax = Axis(fig[1,1], title="Observation - Runoff", ylabel="N of basins", xlabel="Relative difference")
    hist!(ax, obs_diffs, bins=100)
    text!(-4.9, 100, text = "N of outliers: $obs_outliers")
    save("article/png_files/mass_hist_obs.png", fig)

    # LSTM runoff diff
    fig = Figure()
    ax = Axis(fig[1,1], title="LSTM simulation - Runoff", ylabel="N of basins", xlabel="Relative difference")
    hist!(ax, lstm_diffs, bins=100)
    text!(-4.9, 80, text = "N of outliers: $lstm_outliers")
    save("article/png_files/mass_hist_lstm.png", fig)

    # GloFAS runoff diff using GRDC area
    fig = Figure()
    ax = Axis(fig[1,1], title="GloFAS reanalysis - Runoff using GRDC area", ylabel="N of basins", xlabel="Relative difference")
    hist!(ax, grdc_glofas_diffs, bins=100)
    text!(-4.9, 50, text = "N of outliers: $grdc_glofas_outliers")
    save("article/png_files/mass_hist_grdc_glofas.png", fig)

    # GloFAS runoff diff using GloFAS area
    fig = Figure()
    ax = Axis(fig[1,1], title="GloFAS reanalysis - Runoff using GloFAS area", ylabel="N of basins", xlabel="Relative difference")
    hist!(ax, glofas_glofas_diffs, bins=100)
    text!(-4.9, 50, text = "N of outliers: $glofas_glofas_outliers")
    save("article/png_files/mass_hist_glofas_glofas.png", fig)

    # Upstream area diff
    fig = Figure()
    ax = Axis(fig[1,1], title="GloFAS area - GRDC area", ylabel="N of basins", xlabel="Relative difference")
    hist!(ax, area_diffs, bins=100)
    text!(-1.9, 300, text="N of outliers: $area_outliers")
    save("article/png_files/area_hist.png", fig)

    # Upstream area diff
    fig = Figure()
    ax = Axis(fig[1,1], xlabel="Area size [m2]", ylabel="Relative diff.")
    scatter!(ax, area_sizes, glofas_glofas_diffs)
    # text!(-1.9, 300, text = "N of outliers: $area_outliers")
    save("article/png_files/areas_corr.png", fig)

    # Save off_basins dictionary in a .csv file
    csv_file_path = "article/basins_relativ_diff_dict.csv"
    CSV.write(csv_file_path, DataFrame(basin=off_basins, 
                                       relative_diff=off_relative_diff,
                                       glofas_area=off_areas_glofas,
                                       grdc_area=off_areas_grdc))
end