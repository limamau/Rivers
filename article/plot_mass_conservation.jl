using CairoMakie
using CSV
using DataFrames
using Dates
using JSON
using Statistics

let
    # LSTM model
    data_dir = "/central/scratch/mdemoura/data"
    lstm_sim_dir = "/central/scratch/mdemoura/data/lstm_simulations"
    glofas_sim_dir = "/central/scratch/mdemoura/data/era5/glofas_timeseries"

    obs_diffs = []
    obs_outliers = 0
    lstm_diffs = []
    lstm_outliers = 0
    glofas_diffs = []
    glofas_outliers = 0
    
    files = readdir(lstm_sim_dir)
    for file in files
        # Read basin id
        basin_id = parse(Int, split(split(file, "_")[end], ".")[1])

        # Read timeseries and simulations Data Frames
        lv = string(basin_id)[2:3]
        timeseries_df = CSV.read(joinpath(data_dir, "timeseries/timeseries_lv$lv/basin_$basin_id.csv"), DataFrame)
        attributes_df = CSV.read(joinpath(data_dir, "attributes/attributes_lv$lv/other_attributes.csv"), DataFrame)
        lstm_sim_df = CSV.read(joinpath(lstm_sim_dir, "sim_$basin_id.csv"), DataFrame)

        # Select timeseries date indexes
        ts_min_date_idx = findfirst(date -> date == Date(1991, 01, 01), timeseries_df[:, "date"])
        ts_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), timeseries_df[:, "date"])

        # Select simulations date indexes
        sim_min_date_idx = findfirst(date -> date == Date(1991, 01, 01), lstm_sim_df[:, "date"])
        sim_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), lstm_sim_df[:, "date"])

        # Basin area
        basin_area = attributes_df[attributes_df[:, :basin_id] .== basin_id, "area"][1]

        # Get the sum of variables on time
        runoff = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "sro_sum"] .+ timeseries_df[ts_min_date_idx:ts_max_date_idx, "ssro_sum"]) * basin_area * 1000000
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
        end

        # Push into arrays
        if !isnan(runoff)
            if !isnan(obs_streamflow)
                relative_diff = (obs_streamflow-runoff)/obs_streamflow
                if abs(relative_diff) < 5
                    push!(obs_diffs, relative_diff)
                else
                    println("Basin $basin_id is an outlier!")
                    obs_outliers += 1
                end
            end
            if !isnan(lstm_streamflow)
                relative_diff = (lstm_streamflow-runoff)/lstm_streamflow
                if abs(relative_diff) < 5
                    push!(lstm_diffs, relative_diff)
                else
                    lstm_outliers += 1
                end
            end
            if isfile(gauge_file)
                if !isnan(glofas_streamflow) & (glofas_streamflow != 0)
                    relative_diff = (glofas_streamflow-runoff)/glofas_streamflow
                    if abs(relative_diff) < 5
                        push!(glofas_diffs, relative_diff)
                    else
                        glofas_outliers += 1
                    end
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

    # GloFAS runoff diff
    fig = Figure()
    ax = Axis(fig[1,1], title="GloFAS reanalysis - Runoff", ylabel="N of basins", xlabel="Relative difference")
    hist!(ax, glofas_diffs, bins=100)
    text!(-4.9, 50, text = "N of outliers: $glofas_outliers")
    save("article/png_files/mass_hist_glofas.png", fig)
end