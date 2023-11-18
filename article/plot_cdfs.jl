using CairoMakie
using CSV
using DataFrames
using ProgressMeter
using Statistics

function print_stats(experiment_name::String, arr::Vector{Float64}, metric::String)
     if metric == "nse"
          threshold = 0
     elseif metric == "kge"
          threshold = 1-sqrt(2)
     else
          error("Supported metrics: 'nse' or 'kge'")
     end

     # Median
     arr_median = round(median(arr), digits=2)

     # Unbounded mean
     arr_mean = round(mean(arr), digits=2)

     # Mean of good performances
     arr_good_mean = round(mean([x for x in arr if x > threshold]), digits=2)

     # Porcentage of bad performances
     porc_bad = round(100*length([x for x in arr if x < threshold])/length(arr), digits=2)
     
     # Print
     println("$experiment_name: $porc_bad% / $arr_mean / $arr_good_mean / $arr_median")
end

function fix_outliers()

end

let
     # Define resolution multiplier
     px_per_unit = 4

     # Read used basins from the article folder
     selected_basins = Int[]
     file_path = "article/selected_basins.txt" 
     open(file_path) do file
          for line in eachline(file)
               push!(selected_basins, parse(Int, line))
          end
     end

     println("% of bad / Mean / Good mean / Median")
     
     ### US vs. Globe models
     println("----- NSE -----")
     fig = Figure(resolution=(500,500))
     Axis(fig[1, 1], 
          limits = (0,1,0,1), 
          xlabel = "NSE",
          xlabelsize = 17,
          ylabel = "CDF",
          ylabelsize = 17,
          xticks = 0:0.25:1,
          yticks = 0:0.25:1)

     # Get scores in USA
     csv_file = "article/csv_files/us_split_daily_runoff.csv"
     us_results_df = CSV.read(csv_file, DataFrame)
     basin_us_nse_values = us_results_df[:,:nse]
     print_stats("US, basin-split", basin_us_nse_values, "nse")

     csv_file = "article/csv_files/us_all_daily_runoff.csv"
     us_results_df = CSV.read(csv_file, DataFrame)
     time_us_nse_values = us_results_df[:,:nse]
     print_stats("US, time-split", time_us_nse_values, "nse")

     csv_file = "article/csv_files/us_all_daily_precip.csv"
     us_results_df = CSV.read(csv_file, DataFrame)
     precip_time_us_nse_values = us_results_df[:,:nse]
     print_stats("US, time-split (precip.)", precip_time_us_nse_values, "nse")

     # Get global scores
     csv_file = "article/csv_files/globe_split_daily.csv"
     global_results_df = CSV.read(csv_file, DataFrame)
     basin_global_nse_values = global_results_df[:,:nse]
     print_stats("Globe, basin-split", basin_global_nse_values, "nse")

     csv_file = "article/csv_files/globe_all_daily.csv"
     global_results_df = CSV.read(csv_file, DataFrame)
     time_global_nse_values = global_results_df[:,:nse]
     print_stats("Globe, time-split", time_global_nse_values, "nse")

     # Plot curves
     ecdfplot!(basin_us_nse_values, color=:dodgerblue2, label="USA - basin split (runoff)", linestyle=:dash)
     ecdfplot!(time_us_nse_values, color=:dodgerblue2, label="USA - time split (runoff)")
     ecdfplot!(precip_time_us_nse_values, color=:indigo, label="USA - time split (precip.)")
     ecdfplot!(basin_global_nse_values, color=:red, label="Global - basin split (runoff)", linestyle=:dash)
     ecdfplot!(time_global_nse_values, color=:red, label="Global - time split (runoff)")
     axislegend(position=(0,1))

     # Save
     output_file = "article/png_files/nse_cdfs/us_vs_global.png"
     mkpath(dirname(output_file))
     save(output_file, fig, px_per_unit=px_per_unit)

     ### Benchmarks NSE
     println("----- NSE -----")
     fig = Figure(resolution=(500,500))
     ax = Axis(fig[1,1], 
               limits = (0,1,0,1), 
               xlabel = "NSE",
               xlabelsize = 17,
               ylabel = "CDF",
               ylabelsize = 17,
               xticks = 0:0.25:1,
               yticks = 0:0.25:1)

     # Get LSTM scores
     csv_file = "article/csv_files/globe_all_daily.csv"
     time_lstm_results_df = CSV.read(csv_file, DataFrame)
     time_lstm_results_df = filter(row -> row.basin in selected_basins, time_lstm_results_df)
     time_lstm_nse_values = time_lstm_results_df[:,:nse]
     print_stats("LSTM, time-split", time_lstm_nse_values, "nse")

     # Get LSTM scores
     csv_file = "article/csv_files/globe_split_daily.csv"
     basin_lstm_results_df = CSV.read(csv_file, DataFrame)
     basin_lstm_results_df = filter(row -> row.basin in selected_basins, basin_lstm_results_df)
     basin_lstm_nse_values = basin_lstm_results_df[:,:nse]
     print_stats("LSTM, basin-split", basin_lstm_nse_values, "nse")

     # Get GloFAS scores
     csv_file = "article/csv_files/glofas_daily.csv"
     glofas_results_df = CSV.read(csv_file, DataFrame)
     glofas_results_df = filter(row -> row.basin in selected_basins, glofas_results_df)
     glofas_nse_values = glofas_results_df[:,:nse]
     print_stats("GloFAS-ERA5", glofas_nse_values, "nse")
     glofas_nse_values .= max.(-10, glofas_nse_values)

     # Plot curves
     ecdfplot!(basin_lstm_nse_values, color=:red, label="LSTM - basin split", linestyle=:dash)
     ecdfplot!(time_lstm_nse_values, color=:red, label="LSTM - time split")
     ecdfplot!(glofas_nse_values, color=:green, label="GloFAS-ERA5")
     axislegend(position=(0,1))

     # Save
     output_file = "article/png_files/nse_cdfs/lstm_vs_benchmarks.png"
     mkpath(dirname(output_file))
     save(output_file, fig, px_per_unit=px_per_unit)

     ### Benchmarks KGE
     println("----- KGE -----")
     fig = Figure(resolution=(500,500))
     ax = Axis(fig[1,1], 
               limits = (1-√2,1,0,1), 
               xlabel = "KGE",
               xlabelsize = 17,
               ylabel = "CDF",
               ylabelsize = 17,
               xticks =  (1-√2:√2/4:1, [string(round(x,digits=2)) for x in 1-√2:√2/4:1]),
               yticks = 0:0.25:1)
     ax.ylabelcolor = :white
     ax.yticklabelcolor = :white
     ax.ytickcolor = :white

     # Get LSTM scores
     csv_file = "article/csv_files/globe_all_daily.csv"
     time_lstm_results_df = CSV.read(csv_file, DataFrame)
     time_lstm_results_df = filter(row -> row.basin in selected_basins, time_lstm_results_df)
     time_lstm_kge_values = time_lstm_results_df[:,:kge]
     print_stats("LSTM, time-split", time_lstm_kge_values, "kge")

     # Get LSTM scores
     csv_file = "article/csv_files/globe_split_daily.csv"
     basin_lstm_results_df = CSV.read(csv_file, DataFrame)
     basin_lstm_results_df = filter(row -> row.basin in selected_basins, basin_lstm_results_df)
     basin_lstm_kge_values = basin_lstm_results_df[:,:kge]
     print_stats("LSTM, basin-split", basin_lstm_kge_values, "kge")

     # Get GloFAS scores
     csv_file = "article/csv_files/glofas_daily.csv"
     glofas_results_df = CSV.read(csv_file, DataFrame)
     glofas_results_df = filter(row -> row.basin in selected_basins, glofas_results_df)
     glofas_kge_values = glofas_results_df[:,:kge]
     print_stats("GloFAS-ERA5", glofas_kge_values, "kge")
     glofas_kge_values .= max.(-10, glofas_kge_values)

     # Plot curves
     ecdfplot!(basin_lstm_kge_values, color=:red, label="LSTM - basin split", linestyle=:dash)
     ecdfplot!(time_lstm_kge_values, color=:red, label="LSTM - time split")
     ecdfplot!(glofas_kge_values, color=:green, label="GloFAS-ERA5")

     # Save
     output_file = "article/png_files/kge_cdfs/lstm_vs_benchmarks.png"
     mkpath(dirname(output_file))
     save(output_file, fig, px_per_unit=px_per_unit)

     # Print lengths
     println("----- L -----")
     println("Length LSTM basin split: ", length(basin_lstm_nse_values))
     println("Length LSTM time split: ", length(time_lstm_nse_values))
     println("Length GloFAS: ", length(glofas_nse_values))
end