using CairoMakie
using CSV
using DataFrames
using ProgressMeter

for metric in ["nse", "kge"]
     ### US vs. Globe models
     fig = Figure()
     Axis(fig[1, 1], 
          limits = (0,1,0,1), 
          xlabel = uppercase(metric),
          ylabel = "CDF",
          # title = "US vs. Globe models",
          xticks = 0:0.2:1,
          yticks = 0:0.2:1)

     # Get scores in USA
     csv_file = "article/csv_files/us_split_daily_runoff.csv"
     us_results_df = CSV.read(csv_file, DataFrame)
     basin_us_metric_values = us_results_df[:,metric]

     csv_file = "article/csv_files/us_all_daily_runoff.csv"
     us_results_df = CSV.read(csv_file, DataFrame)
     time_us_metric_values = us_results_df[:,metric]

     csv_file = "article/csv_files/us_all_daily_precip.csv"
     us_results_df = CSV.read(csv_file, DataFrame)
     precip_time_us_metric_values = us_results_df[:,metric]

     # Get global scores
     csv_file = "article/csv_files/globe_split_daily.csv"
     global_results_df = CSV.read(csv_file, DataFrame)
     basin_global_metric_values = global_results_df[:,metric]

     csv_file = "article/csv_files/globe_all_daily.csv"
     global_results_df = CSV.read(csv_file, DataFrame)
     time_global_metric_values = global_results_df[:,metric]

     # Plot curves
     ecdfplot!(basin_us_metric_values, color=:dodgerblue2, label="USA model - Basin split", linestyle=:dash)
     ecdfplot!(time_us_metric_values, color=:dodgerblue2, label="USA model - Time split")
     ecdfplot!(precip_time_us_metric_values, color=:indigo, label="USA model - Time split (precip.)")
     ecdfplot!(basin_global_metric_values, color=:firebrick1, label="Global model - Basin split", linestyle=:dash)
     ecdfplot!(time_global_metric_values, color=:firebrick1, label="Global model - Time split")
     axislegend(position=(0,1))

     # Save
     output_file = "article/png_files/"*metric*"_cdfs/us_vs_global.png"
     mkpath(dirname(output_file))
     save(output_file, fig, px_per_unit = 2)

     ### Benchmarks
     fig = Figure()
     Axis(fig[1, 1], 
          limits = (0,1,0,1), 
          xlabel = uppercase(metric), 
          ylabel = "CDF", 
          # title = "LSTM vs. Benchmarks",
          xticks = 0:0.2:1,
          yticks = 0:0.2:1)

     # Get LSTM scores
     csv_file = "article/csv_files/globe_all_daily.csv"
     time_lstm_results_df = CSV.read(csv_file, DataFrame)
     time_lstm_metric_values = time_lstm_results_df[:,metric]

     # Get LSTM scores
     csv_file = "article/csv_files/globe_split_daily.csv"
     basin_lstm_results_df = CSV.read(csv_file, DataFrame)
     basin_lstm_metric_values = basin_lstm_results_df[:,metric]

     # Get GloFAS scores
     csv_file = "article/csv_files/glofas_daily.csv"
     glofas_results_df = CSV.read(csv_file, DataFrame)
     glofas_metric_values = glofas_results_df[:,metric]

     for i in eachindex(glofas_metric_values)
          if glofas_metric_values[i] < -1000
               glofas_metric_values[i] = -1
          end
     end

     # Get PCR-GLOBWB2 scores
     csv_file = "article/csv_files/pcr_monthly.csv"
     pcr_results_df = CSV.read(csv_file, DataFrame)
     pcr_metric_values = pcr_results_df[:,metric]

     for i in eachindex(pcr_metric_values)
          if pcr_metric_values[i] < -1000
               pcr_metric_values[i] = -1
          end
     end

     # Plot curves
     ecdfplot!(basin_lstm_metric_values, color=:firebrick1, label="LSTM - Basin split", linestyle=:dash)
     ecdfplot!(time_lstm_metric_values, color=:firebrick1, label="LSTM - Time split")
     ecdfplot!(glofas_metric_values, color=:forestgreen, label="GloFAS-ERA5 (daily)")
     # ecdfplot!(pcr_metric_values, color=:turquoise3, label="PCR-GLOBWB2 (monthly)")
     axislegend(position=(0,1))

     # Save
     output_file = "article/png_files/"*metric*"_cdfs/lstm_vs_benchmarks.png"
     mkpath(dirname(output_file))
     save(output_file, fig, px_per_unit = 2)
end