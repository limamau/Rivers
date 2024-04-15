using CairoMakie
using CSV
using DataFrames
using Dates
using JSON
using NCDatasets
using Statistics

function main()
    # LSTM scores DataFrame
    base = "/central/scratch/mdemoura/Rivers"
    lstm_scores_df = CSV.read("examples/catchment_models/analysis/csv_files/globe_all_daily.csv", DataFrame)

    # GloFAS scores DataFrame
    glofas_scores_df = CSV.read("examples/catchment_models/analysis/csv_files/glofas_daily.csv", DataFrame)

    # Bad, median, good LSTM, good GloFAS
    basin_ids = [1061638580, 6050344660, 7070250410, 7060363050]

    # Read gauge information
    grdc_nc_file = joinpath(base, "midway_data/GRDC-Globe/grdc-merged.nc")
    grdc_nc = NCDataset(grdc_nc_file)
    grdc_lons = grdc_nc["geo_x"][:]
    grdc_lats = grdc_nc["geo_y"][:]
    grdc_ids = grdc_nc["gauge_id"][:]

    # Letter for organizing plots
    letters = ["a", "b", "c", "d"]

    # Index of subplots
    idxs = [(1,1), (1,2), (2,1), (2,2)]

    # Figure
    fig = Figure(resolution = (1000, 1000))

    # Iterate over sub plots
    for (basin_id, letter, (i,j)) in zip(basin_ids, letters, idxs)
        # Get HydroSHEDS level
        lv = string(basin_id)[2:3]

        # Read files
        lstm_df = CSV.read(joinpath(base, "post_data/lstm_simulations/sim_$basin_id.csv"), DataFrame)
        glofas_df = CSV.read(joinpath(base, "post_data/glofas_timeseries/sim_$basin_id.csv"), DataFrame)
        
        # Define figure and axis
        if letter == "a"
            ax = Axis(fig[i,j], ylabel="Discharge (m³/s)", ylabelpadding=25, ylabelsize=17, xticklabelsvisible=false, xticksvisible=false)
        elseif letter == "b"
            ax = Axis(fig[i,j], xticklabelsvisible=false, xticksvisible=false)
        elseif letter == "c"
            ax = Axis(fig[i,j], xlabel="Dates", xlabelsize=17, ylabel="Discharge (m³/s)", ylabelsize=17)
        elseif letter == "d"
            ax = Axis(fig[i,j], xlabel="Dates", xlabelsize=17)
        end
        hidedecorations!(ax, ticklabels=false, ticks=false, label=false)

        # Select date indexes
        lstm_min_date_idx = findfirst(date -> date == Date(1996, 01, 01), lstm_df[:, "date"])
        lstm_max_date_idx = findfirst(date -> date == Date(1998, 12, 31), lstm_df[:, "date"])

        # Select date indexes
        glofas_min_date_idx = findfirst(date -> date == Date(1996, 01, 01), glofas_df[:, "date"])
        glofas_max_date_idx = findfirst(date -> date == Date(1998, 12, 31), glofas_df[:, "date"])

        # Plot lines
        lines!(ax, lstm_min_date_idx:lstm_max_date_idx, glofas_df[glofas_min_date_idx:glofas_max_date_idx, "sim"], label="GloFAS ERA5", transparency=true, color=:lime, linewidth=2)
        lines!(ax, lstm_min_date_idx:lstm_max_date_idx, lstm_df[lstm_min_date_idx:lstm_max_date_idx, "sim"], label="LSTM", transparency=true, color=:magenta, linewidth=2)
        lines!(ax, lstm_min_date_idx:lstm_max_date_idx, lstm_df[lstm_min_date_idx:lstm_max_date_idx, "obs"], label="Observed", transparency=true, color=:dodgerblue, linewidth=2)
        ax.xticks = (lstm_min_date_idx+30:365:lstm_max_date_idx+30, string.(lstm_df[:, "date"])[lstm_min_date_idx+30:365:lstm_max_date_idx+30])
        ax.xticklabelrotation = π/4

        if letter == "b"
            axislegend(ax)
        end

        # Get NSE and KGE scores for the LSTM model
        row = lstm_scores_df[lstm_scores_df.basin .== basin_id, :]
        lstm_nse = round(row.nse[1], digits=2)
        lstm_kge = round(row.kge[1], digits=2)

        # Get NSE and KGE scores for GloFAS data
        row = glofas_scores_df[glofas_scores_df.basin .== basin_id, :]
        glofas_nse = round(row.nse[1], digits=2)
        glofas_kge = round(row.kge[1], digits=2)
        
        # Print scores
        println("-------------")
        println("$letter)")
        println("LSTM: $lstm_nse/$lstm_kge")
        println("GloFAS: $glofas_nse/$glofas_kge")

        # Read basin-gauge mapping dictionary and get corresponding gauge
        basin_gauge_json_file = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv$lv"*"_max.json")
        basin_gauge_dict = JSON.parsefile(basin_gauge_json_file)
        gauge_id = basin_gauge_dict[string(basin_id)][1]

        # Print (lat,lon) of corresponding gauge
        gauge_idx = findfirst(id -> id == gauge_id, grdc_ids)
        lon = grdc_lons[gauge_idx]
        lat = grdc_lats[gauge_idx]
        println("lat,lon: $lat,$lon")
    end

    # Save figure
    save("examples/catchment_models/analysis/png_files/streamflows.png", fig, px_per_unit=4)
end

main()