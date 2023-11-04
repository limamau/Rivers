using CairoMakie
using CSV
using DataFrames
using ProgressMeter
using Statistics

function print_meand_median(experiment_name, arr)
     arr_mean = round(mean(arr), digits=2)
     arr_median = round(median(arr), digits=2)
     println("$experiment_name: $arr_mean / $arr_median")
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

     for metric in ["nse", "kge"]
          println("-------"*uppercase(metric)*"-------")
          
          ### US vs. Globe models
          fig = Figure(resolution=(500,500))
          Axis(fig[1, 1], 
               limits = (0,1,0,1), 
               xlabel = uppercase(metric),
               xlabelsize = 17,
               ylabel = "CDF",
               ylabelsize = 17,
               xticks = 0:0.2:1,
               yticks = 0:0.2:1)

          # Get scores in USA
          csv_file = "article/csv_files/us_split_daily_runoff.csv"
          us_results_df = CSV.read(csv_file, DataFrame)
          basin_us_metric_values = us_results_df[:,metric]
          print_meand_median("US, basin-split:", basin_us_metric_values)

          csv_file = "article/csv_files/us_all_daily_runoff.csv"
          us_results_df = CSV.read(csv_file, DataFrame)
          time_us_metric_values = us_results_df[:,metric]
          print_meand_median("US, time-split", time_us_metric_values)

          csv_file = "article/csv_files/us_all_daily_precip.csv"
          us_results_df = CSV.read(csv_file, DataFrame)
          precip_time_us_metric_values = us_results_df[:,metric]
          print_meand_median("US, time-split (precip.)", precip_time_us_metric_values)

          # Get global scores
          csv_file = "article/csv_files/globe_split_daily.csv"
          global_results_df = CSV.read(csv_file, DataFrame)
          basin_global_metric_values = global_results_df[:,metric]
          print_meand_median("Globe, basin-split", basin_global_metric_values)

          csv_file = "article/csv_files/globe_all_daily.csv"
          global_results_df = CSV.read(csv_file, DataFrame)
          time_global_metric_values = global_results_df[:,metric]
          print_meand_median("Globe, time-split", time_global_metric_values)

          # Plot curves
          ecdfplot!(basin_us_metric_values, color=:dodgerblue2, label="USA - basin split", linestyle=:dash)
          ecdfplot!(time_us_metric_values, color=:dodgerblue2, label="USA - time split")
          ecdfplot!(precip_time_us_metric_values, color=:indigo, label="USA - time split (precip.)")
          ecdfplot!(basin_global_metric_values, color=:red, label="Global - basin split", linestyle=:dash)
          ecdfplot!(time_global_metric_values, color=:red, label="Global - time split")
          axislegend(position=(0,1))

          # Save
          output_file = "article/png_files/"*metric*"_cdfs/us_vs_global.png"
          mkpath(dirname(output_file))
          save(output_file, fig, px_per_unit = 2)

          ### Benchmarks
          fig = Figure(resolution=(500,500))
          ax = Axis(fig[1,1], 
                   limits = (0,1,0,1), 
                   xlabel = uppercase(metric),
                   xlabelsize = 17,
                   ylabel = "CDF",
                   ylabelsize = 17,
                   xticks = 0:0.2:1,
                   yticks = 0:0.2:1)
          if metric == "kge"
               ax.ylabelcolor = :white
               ax.yticklabelcolor = :white
               ax.ytickcolor = :white
          end

          # Get LSTM scores
          csv_file = "article/csv_files/globe_all_daily.csv"
          time_lstm_results_df = CSV.read(csv_file, DataFrame)
          time_lstm_results_df = filter(row -> row.basin in selected_basins, time_lstm_results_df)
          time_lstm_metric_values = time_lstm_results_df[:,metric]
          print_meand_median("LSTM, time-split", time_lstm_metric_values)

          # Get LSTM scores
          csv_file = "article/csv_files/globe_split_daily.csv"
          basin_lstm_results_df = CSV.read(csv_file, DataFrame)
          basin_lstm_results_df = filter(row -> row.basin in selected_basins, basin_lstm_results_df)
          basin_lstm_metric_values = basin_lstm_results_df[:,metric]
          print_meand_median("LSTM, basin-split", basin_lstm_metric_values)

          # Get GloFAS scores
          csv_file = "article/csv_files/glofas_daily.csv"
          glofas_results_df = CSV.read(csv_file, DataFrame)
          glofas_results_df = filter(row -> row.basin in selected_basins, glofas_results_df)
          glofas_metric_values = glofas_results_df[:,metric]
          print_meand_median("GloFAS-ERA5", glofas_metric_values)

          # Fix too big values
          for i in eachindex(glofas_metric_values)
               if glofas_metric_values[i] < -1000
                    glofas_metric_values[i] = -10
               end
          end

          # Plot curves
          ecdfplot!(basin_lstm_metric_values, color=:red, label="LSTM - Basin split", linestyle=:dash)
          ecdfplot!(time_lstm_metric_values, color=:red, label="LSTM - Time split")
          ecdfplot!(glofas_metric_values, color=:green, label="GloFAS-ERA5 (daily)")

          # Save
          output_file = "article/png_files/"*metric*"_cdfs/lstm_vs_benchmarks.png"
          mkpath(dirname(output_file))
          save(output_file, fig, px_per_unit = 4)
     end
end