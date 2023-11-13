using CairoMakie
using CSV
using DataFrames
using Dates
using JSON
using ProgressMeter
using Statistics

function allocate_relative_difference!(val1::Real, val2::Real, histogram_array::Vector{Float64}, n_outliers::Real, threshold::Real)
    if !isnan(val1) & (val1 != 0)
        relative_diff = (val1 - val2) / max(val1, val2)
        if abs(relative_diff) < threshold
            push!(histogram_array, relative_diff)
        else
            n_outliers += 1
        end
    end

    return n_outliers
end

function allocate_mm_per_year!(val1::Real, 
                               val2::Real, 
                               histogram_array::Vector{Float64}, 
                               area::Real, 
                               aggregation_days::Int, 
                               n_outliers::Real, 
                               threshold::Real)
    m_to_mm = 1000
    days_in_a_year = 365
    if !isnan(val1) & (val1 != 0)
        diff = (val1 - val2) / area / aggregation_days * m_to_mm * days_in_a_year
        if abs(diff) < threshold
            push!(histogram_array, diff)
        else
            n_outliers += 1
        end
    end

    return n_outliers
end

let
    # Define directories
    base_dir = "/central/scratch/mdemoura/Rivers"
    lstm_sim_dir = joinpath(base_dir, "post_data/lstm_simulations")
    glofas_sim_dir = joinpath(base_dir, "post_data/glofas_timeseries")

    # Date constants
    min_date = Date(1991, 01, 01)
    max_date = Date(1999, 09, 30)
    aggregation_days = Dates.value(max_date - min_date)
    km²_to_m² = 10^6

    # Outliers threshold
    threshold = 200

    # Variables to catch and plot off things
    obs_diffs::Vector{Float64} = Float64[]
    obs_outliers = 0
    lstm_diffs::Vector{Float64} = Float64[]
    lstm_outliers = 0
    grdc_glofas_diffs::Vector{Float64} = Float64[]
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
    not_found_basins = 0
    found_basins = 0
    used_basins = []

    # Read JSON with upstream areas from GloFAS
    gauge_area_dict = JSON.parsefile("/central/scratch/mdemoura/Rivers/midway_data/era5/gauge_area_dict.json")
    
    # Read base csv file as DataFrame
    base_csv = "article/csv_files/glofas_daily.csv"
    base_df = CSV.read(base_csv, DataFrame)
    basin_ids = base_df.basin
    @showprogress for basin_id in basin_ids
        # Read timeseries and simulations Data Frames
        lv = string(basin_id)[2:3]
        if !isfile(joinpath(glofas_sim_dir, "sim_$basin_id.csv"))
            not_found_basins += 1
            continue
        end
        found_basins += 1
        push!(used_basins, basin_id)
        
        # Read timeseries
        timeseries_df = CSV.read(joinpath(base_dir, "single_model_data/timeseries/timeseries_lv$lv/basin_$basin_id.csv"), DataFrame)
        other_attributes_df = CSV.read(joinpath(base_dir, "single_model_data/attributes/attributes_lv$lv/other_attributes.csv"), DataFrame)
        hydro_attributes_df = CSV.read(joinpath(base_dir, "single_model_data/attributes/attributes_lv$lv/hydroatlas_attributes.csv"), DataFrame)
        lstm_sim_df = CSV.read(joinpath(lstm_sim_dir, "sim_$basin_id.csv"), DataFrame)
        glofas_sim_df = CSV.read(joinpath(glofas_sim_dir, "sim_$basin_id.csv"), DataFrame)

        # Select timeseries date indexes
        ts_min_date_idx = findfirst(date -> date == min_date, timeseries_df[:, "date"])
        ts_max_date_idx = findfirst(date -> date == max_date, timeseries_df[:, "date"])

        # Select simulations date indexes
        lstm_min_date_idx = findfirst(date -> date == min_date, lstm_sim_df[:, "date"])
        lstm_max_date_idx = findfirst(date -> date == max_date, lstm_sim_df[:, "date"])
        glofas_min_date_idx = findfirst(date -> date == min_date, glofas_sim_df[:, "date"])
        glofas_max_date_idx = findfirst(date -> date == max_date, glofas_sim_df[:, "date"])

        # Basin / catchment area
        basin_area = hydro_attributes_df[hydro_attributes_df[:, :basin_id] .== basin_id, "UP_AREA"][1]
        basin_gauge_dict = JSON.parsefile(joinpath(base_dir, "midway_data/mapping_dicts/gauge_to_basin_dict_lv$lv"*"_max.json"))
        grdc_area = other_attributes_df[other_attributes_df[:, :basin_id] .== basin_id, "area"][1] * km²_to_m²
        gauge_id = basin_gauge_dict[string(basin_id)][1]
        glofas_area = gauge_area_dict[string(gauge_id)] * km²_to_m²

        # Get the sum of variables on time
        grdc_runoff = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "sro_sum"] .+ timeseries_df[ts_min_date_idx:ts_max_date_idx, "ssro_sum"]) * grdc_area 
        glofas_runoff = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "sro_sum"] .+ timeseries_df[ts_min_date_idx:ts_max_date_idx, "ssro_sum"]) * glofas_area
        grdc_precipitation = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "tp_sum"]) * grdc_area
        glofas_precipitation = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "tp_sum"]) * glofas_area
        obs_streamflow = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "streamflow"]) * 24*60*60
        lstm_streamflow = sum(lstm_sim_df[lstm_min_date_idx:lstm_max_date_idx, "sim"]) * 24*60*60
        glofas_streamflow = sum(glofas_sim_df[glofas_min_date_idx:glofas_max_date_idx, "sim"]) * 24*60*60

        # Evaporation calculation
        evaporation_df = CSV.read(joinpath(base_dir, "midway_data/xd_lv$lv"*"_evaporation/basin_$basin_id.csv"), DataFrame)
        e_min_date_idx = findfirst(date -> date == min_date, timeseries_df[:, "date"])
        e_max_date_idx = findfirst(date -> date == max_date, timeseries_df[:, "date"])
        grdc_evaporation = sum(evaporation_df[e_min_date_idx:e_max_date_idx, "e_sum"]) * grdc_area
        glofas_evaporation = sum(evaporation_df[e_min_date_idx:e_max_date_idx, "e_sum"]) * glofas_area

        # P-E
        grdc_p_e = grdc_precipitation + grdc_evaporation
        glofas_p_e = glofas_precipitation + glofas_evaporation

        # Observations
        # obs_outliers = allocate_relative_difference!(obs_streamflow, grdc_runoff, obs_diffs, obs_outliers, threshold)
        obs_outliers = allocate_mm_per_year!(obs_streamflow, grdc_runoff, obs_diffs, grdc_area, aggregation_days, obs_outliers, threshold)
        
        # LSTM simulation
        # lstm_outliers = allocate_relative_difference!(lstm_streamflow, grdc_runoff, lstm_diffs, lstm_outliers, threshold)
        lstm_outliers = allocate_mm_per_year!(lstm_streamflow, grdc_runoff, lstm_diffs, grdc_area, aggregation_days, lstm_outliers, threshold)
        
        # GloFAS simulation with GRDC area
        # grdc_glofas_outliers = allocate_relative_difference!(glofas_streamflow, grdc_runoff, grdc_glofas_diffs, grdc_glofas_outliers, threshold)
        grdc_glofas_outliers = allocate_mm_per_year!(glofas_streamflow, grdc_runoff, grdc_glofas_diffs, grdc_area, aggregation_days, grdc_glofas_outliers, threshold)

        # GloFAS simulation with GloFAS area
        # glofas_glofas_outliers = allocate_relative_difference!(glofas_streamflow, glofas_runoff, glofas_glofas_diffs, glofas_glofas_outliers, threshold)
        glofas_glofas_outliers = allocate_mm_per_year!(glofas_streamflow, glofas_runoff, glofas_glofas_diffs, glofas_area, aggregation_days, glofas_glofas_outliers, threshold)

        # Area histogram
        area_outliers = allocate_relative_difference!(glofas_area, grdc_area, area_diffs, area_outliers, 0.2)
    end

    println("Not found basins: ", not_found_basins)
    println("Found basins: ", found_basins)

    # Plot histograms 
    # LSTM runoff diff
    fig = Figure(resolution = (500, 500))
    ax = Axis(fig[1,1], 
              title="Streamflow (LSTM) / Catchment area - Runoff",
              xlabel="Mass difference (mm/yr)",
              xlabelsize=17,
              ylabel="N of basins",
              ylabelsize=17,
              limits=(-200,200,0,30))
    hist!(ax, lstm_diffs, bins=100, color=:dodgerblue)
    hidedecorations!(ax, ticks=false, ticklabels=false, label=false)
    text!(-threshold+5, 20, text = "N of outliers: $lstm_outliers")
    save("mass_balance/png_files/histogram_a.png", fig, px_per_unit=4)

    # Observation-runoff diff
    fig = Figure(resolution = (500, 500))
    ax = Axis(fig[1,1],
              title="Streamflow (Observations) / Catchment area - Runoff",
              xlabel="Mass difference (mm/yr)",
              xlabelsize=17,
              ylabel="N of basins",
              ylabelsize=17,
              limits=(-200,200,0,30))
    hist!(ax, obs_diffs, bins=100, color=:dodgerblue)
    hidedecorations!(ax, ticks=false, ticklabels=false, label=false)
    text!(-threshold+5, 20, text = "N of outliers: $obs_outliers")
    save("mass_balance/png_files/histogram_b.png", fig, px_per_unit=4)

    # GloFAS runoff diff using GloFAS area
    fig = Figure(resolution = (500, 500))
    ax = Axis(fig[1,1], 
              title="Streamflow (GloFAS) / Upstream area - Runoff",
              xlabel="Mass difference (mm/yr)",
              xlabelsize=17,
              ylabel="N of basins",
              ylabelsize=17,
              limits=(-200,200,0,30))
    hist!(ax, glofas_glofas_diffs, bins=100, color=:dodgerblue)
    hidedecorations!(ax, ticks=false, ticklabels=false, label=false)
    text!(-threshold+5, 20, text = "N of outliers: $glofas_glofas_outliers")
    save("mass_balance/png_files/histogram_c.png", fig, px_per_unit=4)

    # Upstream area diff: GloFAS - GRDC
    fig = Figure(resolution = (500, 500))
    ax = Axis(fig[1,1],
              title="Upstream Area (GloFAS) - Catchment area (GRDC)",
              xlabel="Relative difference",
              xlabelsize=17,
              ylabel="N of basins",
              ylabelsize=17,
              limits=(-0.25,0.25,0,60))
    hist!(ax, area_diffs, bins=100, color=:lightcoral)
    text!(-0.245, 40, text="N of outliers: $area_outliers")
    hidedecorations!(ax, ticks=false, ticklabels=false, label=false)
    save("mass_balance/png_files/histogram_d.png", fig, px_per_unit=4)
end