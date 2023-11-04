using CairoMakie
using CSV
using DataFrames
using Dates
using JSON
using Statistics

function get_letter(i::Int,j::Int)::String
    if i==j==1
        return "a"
    elseif (i==1) & (j==2)
        return "b"
    elseif (i==2) & (j==1)
        return "c"
    elseif i==j==2
        return "d"
    else
        error("Not supported i or j")
    end
end

let
    # LSTM scores DataFrame
    lstm_scores_df = CSV.read("article/csv_files/globe_all_daily.csv", DataFrame)

    # GloFAS scores DataFrame
    glofas_scores_df = CSV.read("article/csv_files/glofas_daily.csv", DataFrame)

    # Bad, median, good LSTM, good GloFAS
    basin_ids = [1061638580, 6050344660, 7070250410, 7060363050]

    # Letter for organizing plots
    letters = ["a", "b", "c", "d"]

    for (basin_id, letter) in zip(basin_ids, letters)
        # Define level
        lv = string(basin_id)[2:3]

        # Read files
        sdf = CSV.read("/central/scratch/mdemoura/Rivers/post_data/lstm_simulations/sim_$basin_id.csv", DataFrame)
        gdf = CSV.read("/central/scratch/mdemoura/Rivers/post_data/glofas_timeseries/sim_$basin_id.csv", DataFrame)
        
        # Define figure and axis
        fig = Figure(resolution = (500, 500))
        ax = Axis(fig[1,1], xlabel="Dates", xlabelsize=17, ylabel="Discharge (m³/day)", ylabelsize=17)
        hidedecorations!(ax, ticklabels=false, ticks=false, label=false)

        # Select date indexes
        lstm_min_date_idx = findfirst(date -> date == Date(1996, 01, 01), sdf[:, "date"])
        lstm_max_date_idx = findfirst(date -> date == Date(1998, 12, 31), sdf[:, "date"])

        # Select date indexes
        glofas_min_date_idx = findfirst(date -> date == Date(1996, 01, 01), gdf[:, "date"])
        glofas_max_date_idx = findfirst(date -> date == Date(1998, 12, 31), gdf[:, "date"])

        # Plot lines
        lines!(ax, lstm_min_date_idx:lstm_max_date_idx, gdf[glofas_min_date_idx:glofas_max_date_idx, "sim"] .* 24*60*60, label="GloFAS ERA5", transparency=true, color=:lime, linewidth=2)
        lines!(ax, lstm_min_date_idx:lstm_max_date_idx, sdf[lstm_min_date_idx:lstm_max_date_idx, "sim"] .* 24*60*60, label="LSTM", transparency=true, color=:magenta, linewidth=2)
        lines!(ax, lstm_min_date_idx:lstm_max_date_idx, sdf[lstm_min_date_idx:lstm_max_date_idx, "obs"] .* 24*60*60, label="Observed", transparency=true, color=:dodgerblue, linewidth=2)
        ax.xticks = (lstm_min_date_idx+30:365:lstm_max_date_idx+30, string.(sdf[:, "date"])[lstm_min_date_idx+30:365:lstm_max_date_idx+30])
        ax.xticklabelrotation = π/4
        axislegend(ax)

        # Save figure
        save("article/png_files/streamflows_$letter.png", fig, px_per_unit=4)

        # Get NSE and KGE scores for the LSTM model
        row = lstm_scores_df[lstm_scores_df.basin .== basin_id, :]
        lstm_nse = round(row.nse[1], digits=2)
        lstm_kge = round(row.kge[1], digits=2)

        # Get NSE and KGE scores for GloFAS data
        row = glofas_scores_df[glofas_scores_df.basin .== basin_id, :]
        glofas_nse = round(row.nse[1], digits=2)
        glofas_kge = round(row.kge[1], digits=2)
        
        # Text to print in the plot
        println("$letter)")
        println("LSTM: $lstm_nse/$lstm_kge")
        println("GloFAS: $glofas_nse/$glofas_kge")
        println("-------------")
    end
end