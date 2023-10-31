using CSV
using CairoMakie
using DataFrames
using JSON
using ProgressMeter
using Shapefile
using Statistics
using ProgressMeter

include("../../benchmarks/utils.jl")

function write_routing_levels(hydrosheds_shp_file::String, graph_dict_file::String, topo_basins_dir::String, routing_basins_dir::String)
    # Read HydroATLAS shapefile as a DataFrame
    df = Shapefile.Table(hydrosheds_shp_file) |> DataFrame

    # Read upstream graph dictionary
    graph_dict = JSON.parsefile(graph_dict_file)

    # Instantiate list of files by topological level
    topo_files = reverse(readdir(topo_basins_dir))
    max_topo_lv = length(topo_files)

    # Instantiate routing graph
    routing_lvs_dict = Dict{Int64, Vector{Int64}}() # ROUTING_LV -> [BASIN_ID1, ..., BASIN_IDN]
    for routing_lv in 1:max_topo_lv
        routing_lvs_dict[routing_lv] = Int64[]
    end

    # Set of already marked basins for the iteration
    marked_basins = Set{Int64}()

    # Iterate over all basins following topological levels from top (far from the ocean) to down (coastal basins)
    msg = "Creatig graph..."
    @showprogress msg for topo_file in topo_files
        # Read list of files in the current topological level 
        topo_basins = Int64[]   
        open(joinpath(topo_basins_dir, topo_file)) do file
            for line in eachline(file)
                push!(topo_basins, parse(Int64, line))
            end
        end
    
        for basin_id in topo_basins
            routing_lv = 1
            current_basin = basin_id
            # Follow path until ocean
            while current_basin != 0
                if !(current_basin in marked_basins)
                    # Add basin in routing level 1 if it hasn't been counted yet
                    push!(routing_lvs_dict[routing_lv], current_basin)
                    push!(marked_basins, current_basin)
                end
                routing_lv += 1
                current_basin = df[df.HYBAS_ID .== current_basin, :NEXT_DOWN][1]
            end
        end
    end

    # Create routing level folder
    if isdir(routing_basins_dir)
        rm(routing_basins_dir, recursive=true)
    end
    mkpath(routing_basins_dir)

    # Write basins by routing level
    msg = "Writing graph..."
    @showprogress msg for routing_lv in 1:max_topo_lv
        selected_basins_file = open(joinpath(routing_basins_dir, "routing_lv"*lpad(routing_lv, 2, "0"))*".txt", "w")
        for basin_id in routing_lvs_dict[routing_lv]
            write(selected_basins_file, "$basin_id\n")
        end
        close(selected_basins_file)
    end
end

function get_results_df(gauged_simulations_dir::String, topo_basins_dir::String, routing_basins_dir::String)::DataFrame
    # Number of files inside directory
    n_files = length(readdir(gauged_simulations_dir))

    # Create arrays to save basins, results and reverse topological level in order
    basin_arr = zeros(Int64, n_files)
    nse_arr = fill(NaN, n_files)
    kge_arr = fill(NaN, n_files)
    topo_lv_arr = zeros(Int64, n_files)
    routing_lv_arr = zeros(Int64, n_files)

    # Iterate over topological levels
    topo_lv = 1
    i = 1
    msg = "Iterating topologically..."
    @showprogress msg for topo_file in readdir(topo_basins_dir, join=true)
        # Read used basins from the article folder
        topo_basins = Int64[]
        open(topo_file) do file
            for line in eachline(file)
                push!(topo_basins, parse(Int64, line))
            end
        end

        # Iterate over each basin in the current topological level
        for basin_id in topo_basins
            file = joinpath(gauged_simulations_dir, "basin_$basin_id.csv")
            
            # Check if files exists
            if isfile(file)
                df = CSV.read(file, DataFrame)
                sim = replace(df[:,:sim], missing => NaN)
                obs = replace(df[:,:obs], missing => NaN)

                # Get scores
                basin_arr[i] = basin_id
                nse = get_nse(obs, sim)
                nse_arr[i] = ismissing(nse) ? NaN : nse
                kge = get_kge(obs, sim)
                kge_arr[i] = ismissing(kge) ? NaN : kge
                topo_lv_arr[i] = topo_lv
                
                # Update i
                i += 1
            end
        end

        # Update topological level
        topo_lv += 1
    end

    # Iterate over routing levels
    routing_lv = 1
    i = 1
    msg = "Iterating over routing levels..."
    @showprogress msg for routing_file in readdir(routing_basins_dir, join=true)
        # Read used basins from the article folder
        routing_basins = Int64[]
        open(routing_file) do file
            for line in eachline(file)
                push!(routing_basins, parse(Int64, line))
            end
        end

        # Iterate over each basin in the routing level
        for basin_id in routing_basins
            # Loop through the indices of basin_arr
            for i in 1:length(basin_arr)
                if basin_arr[i] == basin_id
                    routing_lv_arr[i] = routing_lv
                end
            end 
        end

        # Update topological level
        routing_lv += 1
    end

    return DataFrame(basin=basin_arr, nse=nse_arr, kge=kge_arr, topo_lv=topo_lv_arr, routing_lv=routing_lv_arr)
end

function plot_mean_median(unique_lvs, mean_arr, median_arr, metric, png_files_dir, lv_type)
    # Specific arrays for bars plot
    b_unique_lvs = Int64[]
    b_mean_median = Float64[]
    dodge = Int64[]
    color = []
    for i in 1:length(unique_lvs)
        push!(b_unique_lvs, unique_lvs[i])
        push!(b_unique_lvs, unique_lvs[i])
        push!(b_mean_median, mean_arr[i])
        push!(b_mean_median, median_arr[i])
        push!(dodge, 1)
        push!(dodge, 2)
        push!(color, :red)
        push!(color, :blue)
    end

    # bars plot
    fig = Figure(resolution = (1600, 600))
    Axis(fig[1, 1],
        title = "Complete simulation in Hydro Level 05",
        limits = (0,25,-1,1), 
        xlabel = lv_type == "topo_lv" ? "Topological Levels" : "Routing Levels", 
        ylabel = uppercase(metric),
        xticks = 1:1:length(unique_lvs),
        yticks = -1:0.2:1)
    barplot!(b_unique_lvs, b_mean_median, dodge=dodge, color=color)
    Legend(fig[1,2], [PolyElement(polycolor = c) for c in [:red, :blue]], ["Mean", "Median"], "Metric")
    save(joinpath(png_files_dir, "$metric.png"), fig)
end

function plot_totals(unique_lvs, line_count, nan_count, png_files_dir, lv_type)
    # Specific arrays for bars plot
    b_unique_lvs = Int64[]
    b_totals = Int64[]
    dodge = Int64[]
    color = []
    for i in 1:length(unique_lvs)
        push!(b_unique_lvs, unique_lvs[i])
        push!(b_unique_lvs, unique_lvs[i])
        push!(b_totals, line_count[i])
        push!(b_totals, nan_count[i])
        push!(dodge, 1)
        push!(dodge, 2)
        push!(color, :green)
        push!(color, :purple)
    end

    # bars plot
    fig = Figure(resolution = (1600, 600))
    Axis(fig[1, 1],
        title = "Complete simulation in Hydro Level 05",
        xlabel = lv_type == "topo_lv" ? "Topological Levels" : "Routing Levels", 
        ylabel = "Number of basins",
        xticks = 1:1:length(unique_lvs))
    barplot!(b_unique_lvs, b_totals, dodge=dodge, color=color)
    Legend(fig[1,2], [PolyElement(polycolor = c) for c in [:green, :purple]], ["Total", "NaN"], "Type")
    save(joinpath(png_files_dir, "totals.png"), fig)
end

function plot_plots(df, png_files_dir)
    # Get unique lv values
    topo_lvs = unique(df.topo_lv)
    routing_lvs = unique(df.routing_lv)

    for (lv_type, unique_lvs) in [("topo_lv", topo_lvs), ("routing_lv", routing_lvs)]
        # Initialize arrays to store results
        mean_nse = Float64[]
        median_nse = Float64[]
        mean_kge = Float64[]
        median_kge = Float64[]
        line_count = Int64[]
        nan_count = Int64[]

        # Iterate over unique values
        for lv in unique_lvs
            lv_indices = findall(isequal(lv), df[:, lv_type])
            if !isempty(lv_indices)
                lv_df = df[lv_indices, :]
                
                # Calculate the mean and median of nse
                nse_values = [x for x in lv_df.nse if !isnan(x)]
                if !isempty(nse_values)
                    push!(mean_nse, mean(nse_values))
                    push!(median_nse, median(nse_values))
                else
                    push!(mean_nse, NaN)
                    push!(median_nse, NaN)
                end
                
                # Calculate the mean and median of kge
                kge_values = [x for x in lv_df.kge if !isnan(x)]
                if !isempty(kge_values)
                    push!(mean_kge, mean(kge_values))
                    push!(median_kge, median(kge_values))
                else
                    push!(mean_kge, NaN)
                    push!(median_kge, NaN)
                end
                
                # Calculate the number of lines and NaN values
                push!(line_count, nrow(lv_df))
                push!(nan_count, sum(isnan.(lv_df.nse)))
            end
        end
        # NSE bars plot
        mkpath(joinpath(png_files_dir, lv_type))
        plot_mean_median(unique_lvs, mean_nse, median_nse, "nse", joinpath(png_files_dir, lv_type), lv_type)

        # KGE bars plot
        mkpath(joinpath(png_files_dir, lv_type))
        plot_mean_median(unique_lvs, mean_kge, median_kge, "kge", joinpath(png_files_dir, lv_type), lv_type)

        # Number of gauged basins and NaN values
        mkpath(joinpath(png_files_dir, lv_type))
        plot_totals(unique_lvs, line_count, nan_count, joinpath(png_files_dir, lv_type), lv_type)
    end
end

# Run
let
    # Base
    base = "/central/scratch/mdemoura/Rivers"
    hydro_lv = "05"

    # Create basins list by topological level
    hydrosheds_shp_file = joinpath(base, "source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev$hydro_lv.shp")
    graph_dict_file = joinpath(base, "midway_data/graph_dicts/graph_lv$hydro_lv.json")
    topo_basins_dir = joinpath(base, "midway_data/topological_basins")
    routing_basins_dir = joinpath(base, "midway_data/routing_basins")
    write_routing_levels(hydrosheds_shp_file, graph_dict_file, topo_basins_dir, routing_basins_dir)

    # Get DataFrame with NSE, KGE and correlation scores and topological and routing level of each basin
    gauged_simulations_dir = joinpath(base, "complete_simulation/gauged_simulations/")
    results_df = get_results_df(gauged_simulations_dir, topo_basins_dir, routing_basins_dir)
    results_path = "src/complete_simulation/csv_files"
    mkpath(results_path)
    CSV.write(joinpath(results_path, "results.csv"), results_df)

    # Plot number of basins by reverse topological level

    # Plot CDF for root and descendant basins

    # Plot median and mean NSE by topological and routing level
    png_files_dir = "src/complete_simulation/png_files"
    plot_plots(results_df, png_files_dir)
end