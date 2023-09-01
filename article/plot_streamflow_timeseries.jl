using CairoMakie
using CSV
using DataFrames
using Dates
using JSON
using Statistics

let 
    # Define figure and axis
    fig = Figure(resolution = (1600, 1600))
    basins = [1050014920, 2070510690, 1060030310, 7070437950]

    # LSTM scores DataFrame
    lstm_scores_df = CSV.read("article/csv_files/globe_all_daily.csv", DataFrame)

    # GloFAS scores DataFrame
    glofas_scores_df = CSV.read("article/csv_files/glofas_daily.csv", DataFrame)

    for i in 1:2
        for j in 1:2
            # Define basin
            basin_id = basins[2*(i-1) + j]
            lv = string(basin_id)[2:3]

            # Read file
            sdf = CSV.read("/central/scratch/mdemoura/data/lstm_simulations/sim_$basin_id.csv", DataFrame)

            # Read basin gauge dictionary
            basin_gauge_dict = JSON.parsefile("/central/scratch/mdemoura/data/mapping_dicts/gauge_to_basin_dict_lv$lv"*"_max.json")
            gauge_id = basin_gauge_dict[string(basin_id)][1]
            gdf = CSV.read("/central/scratch/mdemoura/data/era5/glofas_timeseries/gauge_$gauge_id.csv", DataFrame)

            ax = Axis(fig[i,j], ylabel="m^3/day")
            hidedecorations!(ax, ticklabels=false, ticks=false, label=false)

            # Select date indexes
            lstm_min_date_idx = findfirst(date -> date == Date(1995, 01, 01), sdf[:, "date"])
            lstm_max_date_idx = findfirst(date -> date == Date(1997, 12, 31), sdf[:, "date"])

            # Select date indexes
            glofas_min_date_idx = findfirst(date -> date == Date(1995, 01, 01), gdf[:, "date"])
            glofas_max_date_idx = findfirst(date -> date == Date(1997, 12, 31), gdf[:, "date"])

            # Plot lines
            lines!(ax, lstm_min_date_idx:lstm_max_date_idx, gdf[glofas_min_date_idx:glofas_max_date_idx, "glofas_streamflow"] .* 24*60*60, label="GloFAS ERA5", transparency=true, color=:goldenrod1, linewidth=2)
            lines!(ax, lstm_min_date_idx:lstm_max_date_idx, sdf[lstm_min_date_idx:lstm_max_date_idx, "sim"] .* 24*60*60, label="LSTM", transparency=true, color=:orchid, linewidth=2)
            lines!(ax, lstm_min_date_idx:lstm_max_date_idx, sdf[lstm_min_date_idx:lstm_max_date_idx, "obs"] .* 24*60*60, label="Observed", transparency=true, color=:darkseagreen3, linewidth=2)
            ax.xticks = (lstm_min_date_idx+30:365:lstm_max_date_idx+30, string.(sdf[:, "date"])[lstm_min_date_idx+30:365:lstm_max_date_idx+30])
            ax.xticklabelrotation = π/4
            axislegend(ax)

            # Get NSE and KGE scores for the LSTM model
            row = lstm_scores_df[lstm_scores_df.basin .== basin_id, :]
            lstm_nse = round(row.nse[1], digits=2)
            lstm_kge = round(row.kge[1], digits=2)

            # Get NSE and KGE scores for GloFAS data
            row = glofas_scores_df[glofas_scores_df.basin .== basin_id, :]
            glofas_nse = round(row.nse[1], digits=2)
            glofas_kge = round(row.kge[1], digits=2)
            
            # Text to print in the plot
            println("$i, $j")
            println("LSTM: $lstm_nse/$lstm_kge")
            println("GloFAS: $glofas_nse/$glofas_kge")
            println("-------------")
        end
    end

    # Save figure
    save("article/png_files/streamflows.png", fig, px_per_unit=4)
end