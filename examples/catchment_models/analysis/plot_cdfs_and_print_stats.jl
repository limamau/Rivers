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

     # Check if the aray is not empty
     if length(arr) != 0
          # Porcentage of bad performances
          porc_bad = round(100*length([x for x in arr if x < threshold])/length(arr), digits=2)
          
          # Unbounded mean
          # arr_mean = round(mean(arr), digits=2)
          
          # Mean of good performances
          arr_good_mean = round(mean([x for x in arr if x > threshold]), digits=2)

          # Median
          arr_median = round(median(arr), digits=2)

          # Length
          # arr_len = length(arr)
          
          # Print
          println("$experiment_name & $porc_bad% & $arr_good_mean & $arr_median")
     
     else
          # Print
          println("$experiment_name & - & - & - & - & 0")
     end
end

function main()
     # Define resolution multiplier
     px_per_unit = 4

     # Read used basins from the folder
     gauged_selected_basins = Int[]
     file_path = joinpath(@__DIR__, "gauged_selected_basins.txt")
     open(file_path) do file
          for line in eachline(file)
               push!(gauged_selected_basins, parse(Int, line))
          end
     end
     ungauged_selected_basins = Int[]
     file_path = joinpath(@__DIR__, "ungauged_selected_basins.txt")
     open(file_path) do file
          for line in eachline(file)
               push!(ungauged_selected_basins, parse(Int, line))
          end
     end

     println("% of bad / Mean / Good mean / Median")
     
     ### US vs. Globe models
     println("----- NSE -----")
     fig = Figure(resolution=(500,500))
     ax = Axis(
          fig[1, 1], 
          limits = (0,1,0,1), 
          xlabel = "NSE",
          xlabelsize = 17,
          ylabel = "CDF",
          ylabelsize = 17,
          xticks = 0:0.25:1,
          yticks = 0:0.25:1
     )


     # Get scores in USA
     csv_file = joinpath(@__DIR__, "csv_files/us_split_daily_runoff.csv")
     us_results_df = CSV.read(csv_file, DataFrame)
     basin_us_nse_values = us_results_df[:,:nse]
     print_stats("US, basin-split", basin_us_nse_values, "nse")

     csv_file = joinpath(@__DIR__, "csv_files/us_all_daily_runoff.csv")
     us_results_df = CSV.read(csv_file, DataFrame)
     time_us_nse_values = us_results_df[:,:nse]
     print_stats("US, time-split", time_us_nse_values, "nse")

     csv_file = joinpath(@__DIR__, "csv_files/us_all_daily_precip.csv")
     us_results_df = CSV.read(csv_file, DataFrame)
     precip_time_us_nse_values = us_results_df[:,:nse]
     print_stats("US, time-split (precip.)", precip_time_us_nse_values, "nse")

     # Get global scores
     csv_file = joinpath(@__DIR__, "csv_files/globe_split_daily.csv")
     global_results_df = CSV.read(csv_file, DataFrame)
     basin_global_nse_values = global_results_df[:,:nse]
     print_stats("Globe, basin-split", basin_global_nse_values, "nse")

     csv_file = joinpath(@__DIR__, "csv_files/globe_all_daily.csv")
     global_results_df = CSV.read(csv_file, DataFrame)
     time_global_nse_values = global_results_df[:,:nse]
     print_stats("Globe, time-split", time_global_nse_values, "nse")

     # Plot curves
     ecdfplot!(ax, basin_us_nse_values, color=:dodgerblue2, label="USA basin-split (runoff)", linestyle=:dash)
     ecdfplot!(ax, time_us_nse_values, color=:dodgerblue2, label="USA time-split (runoff)")
     ecdfplot!(ax, precip_time_us_nse_values, color=:indigo, label="USA time-split (precip.)")
     ecdfplot!(ax, basin_global_nse_values, color=:red, label="Global basin-split (runoff)", linestyle=:dash)
     ecdfplot!(ax,  time_global_nse_values, color=:red, label="Global time-split (runoff)")
     axislegend(position=(0,1))
     hidedecorations!(ax, ticklabels=false, ticks=false, label=false)

     # Save
     output_file = joinpath(@__DIR__, "png_files/us_vs_global.png")
     mkpath(dirname(output_file))
     save(output_file, fig, px_per_unit=px_per_unit)

     ### Global (time-split) model under each level and under each continent
     println("----- --- -----")
     fig = Figure(resolution=(1000,500))
     ax = Axis(
          fig[1, 2], 
          limits = (0,1,0,1), 
          xlabel = "NSE",
          xlabelsize = 17,
          ylabel = "CDF",
          ylabelsize = 17,
          xticks = 0:0.25:1,
          yticks = 0:0.25:1
     )
     ax.ylabelcolor = :white

     # Global model scores in time-split
     csv_file = joinpath(@__DIR__, "csv_files/globe_all_daily.csv")
     results_df = CSV.read(csv_file, DataFrame)
     lv05_nse_values = filter(row -> string(row.basin)[3] == '5', results_df)[:,:nse]
     print_stats("lv 05", lv05_nse_values, "nse")
     lv06_nse_values = filter(row -> string(row.basin)[3] == '6', results_df)[:,:nse]
     print_stats("lv 06", lv06_nse_values, "nse")
     lv07_nse_values = filter(row -> string(row.basin)[3] == '7', results_df)[:,:nse]
     print_stats("lv 07", lv07_nse_values, "nse")

     # Plot curves
     ecdfplot!(ax, lv05_nse_values, color=:pink, label="Global (time-split) (level 05)")
     ecdfplot!(ax, lv06_nse_values, color=:deeppink, label="Global (time-split) (level 06)")
     ecdfplot!(ax, lv07_nse_values, color=:maroon4, label="Global (time-split) (level 07)")
     axislegend(position=(0,1))
     hidedecorations!(ax, ticklabels=false, ticks=false, label=false)

     ### Global - (basin-split) model under each level and under each continent
     println("----- --- -----")
     ax = Axis(
          fig[1, 1], 
          limits = (0,1,0,1), 
          xlabel = "NSE",
          xlabelsize = 17,
          ylabel = "CDF",
          ylabelsize = 17,
          xticks = 0:0.25:1,
          yticks = 0:0.25:1
     )

     # Global model scores in time-split
     csv_file = joinpath(@__DIR__, "csv_files/globe_split_daily.csv")
     results_df = CSV.read(csv_file, DataFrame)
     lv05_nse_values = filter(row -> string(row.basin)[3] == '5', results_df)[:,:nse]
     print_stats("lv 05", lv05_nse_values, "nse")
     lv06_nse_values = filter(row -> string(row.basin)[3] == '6', results_df)[:,:nse]
     print_stats("lv 06", lv06_nse_values, "nse")
     lv07_nse_values = filter(row -> string(row.basin)[3] == '7', results_df)[:,:nse]
     print_stats("lv 07", lv07_nse_values, "nse")

     # Plot curves
     ecdfplot!(ax, lv05_nse_values, color=:pink, label="Global basin-split (level 05)", linestyle=:dash)
     ecdfplot!(ax, lv06_nse_values, color=:deeppink, label="Global basin-split (level 06)", linestyle=:dash)
     ecdfplot!(ax, lv07_nse_values, color=:maroon4, label="Global basin-split (level 07)", linestyle=:dash)
     axislegend(position=(0,1))
     hidedecorations!(ax, ticklabels=false, ticks=false, label=false)
     
     # Save
     output_file = joinpath(@__DIR__, "png_files/global_hydro_lvs.png")
     mkpath(dirname(output_file))
     save(output_file, fig, px_per_unit=px_per_unit)

     println("Median of lv 05 and 06: ", round(median(vcat(lv05_nse_values, lv06_nse_values)), digits=2))
     println("Median of all levels: ", round(median(vcat(lv05_nse_values, lv06_nse_values, lv07_nse_values)), digits=2))


     ### Print data per continent
     println("----- --- -----")
     continent_names = [
          "Africa", 
          "Europe and Middle East",
          "Siberia",
          "Asia", 
          "Australasia", 
          "South America",
          "North and Central America",
          "Arctic (northern Canada)", 
          "Greenland",
     ]
     continent_numbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9']
     for (continent_name, continent_number) in zip(continent_names, continent_numbers)
          continent_nse_values = filter(row -> string(row.basin)[1] == continent_number, results_df)[:,:nse]
          print_stats(continent_name, continent_nse_values, "nse")
     end
     
     ### Benchmarks 
     ## NSE
     println("----- NSE -----")
     fig = Figure(resolution=(1000,500))
     ax = Axis(
          fig[1,1], 
          limits = (0,1,0,1), 
          xlabel = "NSE",
          xlabelsize = 17,
          xticks = 0:0.25:1,
          ylabel = "CDF",
          ylabelsize = 17,
          yticks = 0:0.25:1
     )

     # Get LSTM scores
     csv_file = joinpath(@__DIR__, "csv_files/globe_all_daily.csv")
     time_lstm_results_df = CSV.read(csv_file, DataFrame)
     time_lstm_results_df = filter(row -> row.basin in gauged_selected_basins, time_lstm_results_df)
     # time_lstm_nse_values = filter(row -> string(row.basin)[3] != '7', time_lstm_results_df)[:,:nse]
     time_lstm_nse_values = time_lstm_results_df[:,:nse]
     print_stats("LSTM, time-split", time_lstm_nse_values, "nse")

     # Get LSTM scores
     csv_file = joinpath(@__DIR__, "csv_files/globe_split_daily.csv")
     basin_lstm_results_df = CSV.read(csv_file, DataFrame)
     basin_lstm_results_df = filter(row -> row.basin in ungauged_selected_basins, basin_lstm_results_df)
     # basin_lstm_nse_values = filter(row -> string(row.basin)[3] != '7', basin_lstm_results_df)[:,:nse]
     basin_lstm_nse_values = basin_lstm_results_df[:,:nse]
     print_stats("LSTM, basin-split", basin_lstm_nse_values, "nse")

     # Get GloFAS gauged scores
     csv_file = joinpath(@__DIR__, "csv_files/glofas_gauged_daily.csv")
     glofas_gauged_results_df = CSV.read(csv_file, DataFrame)
     glofas_gauged_results_df = filter(row -> row.basin in gauged_selected_basins, glofas_gauged_results_df)
     # glofas_nse_values = filter(row -> string(row.basin)[3] != '7', glofas_results_df)[:,:nse]
     glofas_gauged_nse_values = glofas_gauged_results_df[:,:nse]
     print_stats("GloFAS gauged", glofas_gauged_nse_values, "nse")
     glofas_gauged_nse_values .= max.(-10, glofas_gauged_nse_values)

     # Get GloFAS ungauged scores
     csv_file = joinpath(@__DIR__, "csv_files/glofas_ungauged_daily.csv")
     glofas_ungauged_results_df = CSV.read(csv_file, DataFrame)
     glofas_ungauged_results_df = filter(row -> row.basin in ungauged_selected_basins, glofas_ungauged_results_df)
     # glofas_nse_values = filter(row -> string(row.basin)[3] != '7', glofas_results_df)[:,:nse]
     glofas_ungauged_nse_values = glofas_ungauged_results_df[:,:nse]
     print_stats("GloFAS ungauged", glofas_ungauged_nse_values, "nse")
     glofas_ungauged_nse_values .= max.(-10, glofas_ungauged_nse_values)

     # Plot curves
     ecdfplot!(basin_lstm_nse_values, color=:red, label="LSTM basin-split", linestyle=:dash)
     ecdfplot!(glofas_ungauged_nse_values, color=:green, label="GloFAS basin-split*", linestyle=:dash)
     ecdfplot!(time_lstm_nse_values, color=:red, label="LSTM time-split")
     ecdfplot!(glofas_gauged_nse_values, color=:green, label="GloFAS time-split*")
     axislegend(position=(0,1))
     hidedecorations!(ax, ticklabels=false, ticks=false, label=false)

     ## KGE
     println("----- KGE -----")
     ax = Axis(
          fig[1,2], 
          limits = (1-√2,1,0,1), 
          xlabel = "KGE",
          xlabelsize = 17,
          xticks =  (1-√2:√2/4:1, [string(round(x,digits=2)) for x in 1-√2:√2/4:1]),
          ylabel = "CDF",
          ylabelsize = 17,
          yticks = 0:0.25:1
     )
     ax.ylabelcolor = :white

     # Get LSTM scores
     csv_file = joinpath(@__DIR__, "csv_files/globe_all_daily.csv")
     time_lstm_results_df = CSV.read(csv_file, DataFrame)
     time_lstm_results_df = filter(row -> row.basin in gauged_selected_basins, time_lstm_results_df)
     # time_lstm_kge_values = filter(row -> string(row.basin)[3] != '7', time_lstm_results_df)[:,:kge]
     time_lstm_kge_values = time_lstm_results_df[:,:kge]
     print_stats("LSTM, time-split", time_lstm_kge_values, "kge")

     # Get LSTM scores
     csv_file = joinpath(@__DIR__, "csv_files/globe_split_daily.csv")
     basin_lstm_results_df = CSV.read(csv_file, DataFrame)
     basin_lstm_results_df = filter(row -> row.basin in ungauged_selected_basins, basin_lstm_results_df)
     # basin_lstm_kge_values = filter(row -> string(row.basin)[3] != '7', basin_lstm_results_df)[:,:nse]
     basin_lstm_kge_values = basin_lstm_results_df[:,:kge]
     print_stats("LSTM, basin-split", basin_lstm_kge_values, "kge")

     # Get GloFAS gauged scores
     csv_file = joinpath(@__DIR__, "csv_files/glofas_gauged_daily.csv")
     glofas_gauged_results_df = CSV.read(csv_file, DataFrame)
     glofas_gauged_results_df = filter(row -> row.basin in gauged_selected_basins, glofas_gauged_results_df)
     # glofas_kge_values = filter(row -> string(row.basin)[3] != '7', glofas_results_df)[:,:kge]
     glofas_gauged_kge_values = glofas_gauged_results_df[:,:kge]
     print_stats("GloFAS gauged", glofas_gauged_kge_values, "kge")
     glofas_gauged_kge_values .= max.(-10, glofas_gauged_kge_values)

     # Get GloFAS ungauged scores
     csv_file = joinpath(@__DIR__, "csv_files/glofas_ungauged_daily.csv")
     glofas_ungauged_results_df = CSV.read(csv_file, DataFrame)
     glofas_ungauged_results_df = filter(row -> row.basin in ungauged_selected_basins, glofas_ungauged_results_df)
     # glofas_kge_values = filter(row -> string(row.basin)[3] != '7', glofas_results_df)[:,:kge]
     glofas_ungauged_kge_values = glofas_ungauged_results_df[:,:kge]
     print_stats("GloFAS ungauged", glofas_ungauged_kge_values, "kge")
     glofas_ungauged_kge_values .= max.(-10, glofas_ungauged_kge_values)

     # Plot curves
     ecdfplot!(ax, basin_lstm_kge_values, color=:red, label="LSTM (basin-split)", linestyle=:dash)
     ecdfplot!(ax, glofas_ungauged_kge_values, color=:green, label="GloFAS", linestyle=:dash)
     ecdfplot!(ax, time_lstm_kge_values, color=:red, label="LSTM (time-split)")
     ecdfplot!(ax, glofas_gauged_kge_values, color=:green, label="GloFAS")
     hidedecorations!(ax, ticklabels=false, ticks=false, label=false)

     # Save
     output_file = joinpath(@__DIR__, "png_files/lstm_vs_benchmarks.png")
     mkpath(dirname(output_file))
     save(output_file, fig, px_per_unit=px_per_unit)

     # Print lengths
     println("----- L -----")
     println("Length LSTM basin-split: ", length(basin_lstm_nse_values))
     println("Length LSTM time-split: ", length(time_lstm_nse_values))
     println("Length GloFAS gauged: ", length(glofas_gauged_nse_values))
     println("Length GloFAS ungauged: ", length(glofas_ungauged_nse_values))
end

if abspath(PROGRAM_FILE) == @__FILE__
     main()
end
