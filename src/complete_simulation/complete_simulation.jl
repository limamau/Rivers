using CSV
using DataFrames
using Dates
using JSON
using ProgressMeter
using Shapefile
using Statistics
using YAML

function write_attributes(hydroatlas_shapefile::String, graph_dict::Dict, output_dir::String)
    mkpath(output_dir)

    # Read Hydro Atlas shapefile
    attributes_df = Shapefile.Table(hydroatlas_shapefile) |> DataFrame

    # Rename HYBAS_ID column to basin_id
    rename!(attributes_df, :HYBAS_ID => :basin_id)

    # Instantiate new columns
    min_dists = zeros(length(attributes_df.basin_id))
    max_dists = zeros(length(attributes_df.basin_id))
    mean_dists = zeros(length(attributes_df.basin_id))
    max_sides = zeros(length(attributes_df.basin_id))
    is_routings = zeros(length(attributes_df.basin_id))

    # Get dists list
    for (i,basin_id) in enumerate(attributes_df.basin_id)
        is_routing = 0
        if !isempty(graph_dict[string(basin_id)])
            is_routing = 1
            dists = []
            down_dist = attributes_df[attributes_df.basin_id .== basin_id, :DIST_MAIN][1]
            for up_basin in graph_dict[string(basin_id)]
                up_dist = attributes_df[attributes_df.basin_id .== up_basin, :DIST_MAIN][1]
                dist = down_dist - up_dist
                push!(dists, dist)
            end
            min_dists[i] = minimum(dists)
            max_dists[i] = maximum(dists)
            mean_dists[i] = mean(dists)
            is_routings[i] = is_routing
        end
        # min_lon, max_lon, min_lat, max_lat = find_min_max_lon_lat(attributes_df[attributes_df.basin_id .== basin_id, :geometry][1].points, 0.0)
        # max_sides[i] = max(max_lon-min_lon, max_lat-min_lat)
    end

    # Add columns
    attributes_df[!, "min_dist"] = min_dists
    attributes_df[!, "max_dist"] = max_dists
    attributes_df[!, "mean_dist"] = mean_dists
    attributes_df[!, "max_side"] = max_sides
    attributes_df[!, "is_routing"] = is_routings

    # Discard geomtry column
    select!(attributes_df, Not([:geometry]))

    # Sort
    sort!(attributes_df)

    # Rename area column
    rename!(attributes_df, "SUB_AREA" => "area")

    # Write csv
    CSV.write(joinpath(output_dir, "attributes.csv"), attributes_df)
end

function write_timeseries(xd_dir::String, timeseries_dir::String, start_date::Date, end_date::Date)
    mkpath(timeseries_dir)
    # Iterate over all files
    msg = "Writing new timeseries files"
    @showprogress msg for file in readdir(xd_dir)
        # Read file as DataFrame
        df = CSV.read(joinpath(xd_dir, file), DataFrame)
        
        # Filter the DataFrame between start_date and end_date
        df = filter(row -> start_date <= row.date <= end_date, df)

        # Add columns for 'streamflow' and 'upstream' filled with zeros
        df[!, :streamflow] .= 0.0
        df[!, :upstream] .= 0.0

        # Save file in new dedicated folder
        CSV.write(joinpath(timeseries_dir, file), df)
    end
end

function write_topo_basins(hydroatlas_shapefile::String, hydro_lv::String, output_dir::String)
    # Read HydroATLAS shapefile as a DataFrame
    df = Shapefile.Table(hydroatlas_shapefile) |> DataFrame

    # Instantiate graph
    graph = Dict{Int64, Vector{Int64}}() # HYBAS -> (NEXT_UP_1, ..., NEXT_UP_N)

    # Iterate over all basins
    for i in 1:length(df.HYBAS_ID)
        # Insert the basin in the graph with an empty vector for upstreams
        graph[df.HYBAS_ID[i]] = []
    end

    # Array with basin of the same topology (same order in respect to the pathway to the ocean)
    topo_array = []

    # Iterate over all basins
    for i in 1:length(df.HYBAS_ID)
        # Check if downstream exists in the graph
        if df.NEXT_DOWN[i] != 0
            # Add basin to the list of upstreams
            push!(graph[df.NEXT_DOWN[i]], df.HYBAS_ID[i])
        else
            push!(topo_array, df.HYBAS_ID[i])
        end
    end

    # Create output directory
    mkpath(output_dir)

    topo_lv = 1
    while !isempty(topo_array)
        # Define file name
        file_name = joinpath(output_dir, "topo_lv"*lpad(topo_lv, 2, "0")*".txt")
        
        # Open the file in write mode
        file = open(file_name, "w")
        
        # Write list of all basin in the same topological topo_lv
        for basin_id in topo_array
            write(file, "$basin_id\n")
        end
        close(file)

        # Repopulate topo_array
        aux_array = []
        for basin_id in topo_array
            aux_array = vcat(aux_array, graph[basin_id])
        end
        topo_array = aux_array
        topo_lv += 1
    end
end

function copy_model(output_dir::String, run_dir::String, epoch::Int64)
    # Create directory to save model
    mkpath(output_dir)

    # Copy key files
    cp(joinpath(run_dir, "config.yml"), joinpath(output_dir, "config.yml"), force=true)
    cp(joinpath(run_dir, "model_epoch0$epoch.pt"), joinpath(output_dir, "model_epoch0$epoch.pt"), force=true)
    cp(joinpath(run_dir, "optimizer_state_epoch0$epoch.pt"), joinpath(output_dir, "optimizer_state_epoch0$epoch.pt"), force=true)
    cp(joinpath(run_dir, "train_data"), joinpath(output_dir, "train_data"), force=true)

    # Change config.yml parameters
    data = YAML.load_file(joinpath(output_dir, "config.yml"); dicttype=Dict{Symbol,Any})
    data[:data_dir] = "/central/scratch/mdemoura/Rivers/complete_simulation"
    data[:run_dir] = output_dir
    YAML.write_file(joinpath(output_dir, "config.yml"), data)
end

let
    # Base
    base = "/central/scratch/mdemoura/Rivers"

    # Define initial variables
    hydro_lv = "05"
    start_date = Date(1991, 06, 23)
    end_date = Date(1999, 9, 30) # this date must be the same end date as the simulation
    run_dir = "/home/mdemoura/Rivers/src/neuralhydrology/graph-models/01-Applied-Source-Filters/runs/all_128_Ard_1308_041441"
    epoch = 32

    # Write timeseries in the dedicated folder with 0s in streamflow column
    xd_dir = joinpath(base, "midway_data/xd_lv$hydro_lv")
    timeseries_dir = joinpath(base, "complete_simulation/timeseries/timeseries_lv$hydro_lv")
    write_timeseries(xd_dir, timeseries_dir, start_date, end_date)

    # Attribute attributes for all the basins
    hydrosheds_shp_file = joinpath(base, "source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev$hydro_lv.shp")
    graph_dict = JSON.parsefile(joinpath(base, "midway_data/graph_dicts/graph_lv$hydro_lv.json"))
    attributes_dir = joinpath(base, "complete_simulation/attributes/attributes_lv$hydro_lv")
    # write_attributes(hydrosheds_shp_file, graph_dict, attributes_dir)

    # Create basins list by topological level
    topo_basins_dir = joinpath(base, "midway_data/topological_basins")
    # write_topo_basins(hydrosheds_shp_file, hydro_lv, topo_basins_dir)

    # Copy model folder
    model_dir = joinpath("src/complete_simulation/model")
    # copy_model(model_dir, run_dir, epoch)

    # Amount of lines in each file
    n_lines = Int(Dates.value(end_date - start_date)) + 1

    # Simulations directory
    simulations_dir = joinpath(base, "complete_simulation/simulations/simulations_lv$hydro_lv/")
    if isdir(simulations_dir)
        rm(simulations_dir, recursive=true)
    end
    mkpath(simulations_dir)

    # Iterate over all topological levels
    basins_files = reverse(readdir(topo_basins_dir, join=true))
    topo_lv = length(basins_files)
    for basins_file in basins_files
        println("Simulating topological level $topo_lv...")

        # Read list of basins
        basins_list = Int[]
        open(basins_file) do file
            for line in eachline(file)
                push!(basins_list, parse(Int, line))
            end
        end
        
        # Calculate upstreams for each basin
        for basin_id in basins_list
            # Check if basin has upstreams
            if !isempty(graph_dict[string(basin_id)])
                # Array to save upstream
                upstreams = zeros(Float64, n_lines)

                # Sum streamflow for all upstreams to get upstreams array
                for up_basin_id in graph_dict[string(basin_id)]
                    upstreams += CSV.read(joinpath(timeseries_dir, "basin_$up_basin_id.csv"), DataFrame)[:, :streamflow]
                end

                # Save new upstream column
                df = CSV.read(joinpath(timeseries_dir, "basin_$basin_id.csv"), DataFrame)
                df[!, "upstream"] .= upstreams
                CSV.write(joinpath(timeseries_dir, "basin_$basin_id.csv"), df)
            end
        end

        # Use current topological level to simulate basins
        data = YAML.load_file(joinpath(model_dir, "config.yml"); dicttype=Dict{Symbol,Any})
        data[:test_basin_file] = basins_file
        YAML.write_file(joinpath(model_dir, "config.yml"), data)

        # Simulate streamflow for all basins in current topological level
        python_script = joinpath("src/complete_simulation/simulate_basins.py")
        run(`python3 $python_script --epoch $epoch --model_dir $model_dir --hydro_lv $hydro_lv`) # make sure to use neuralhydrolgy as env

        # Substitue streamflow series by simulation
        for basin_id in basins_list
            timeseries_df = CSV.read(joinpath(base, timeseries_dir, "basin_$basin_id.csv"), DataFrame)
            simulation_df = CSV.read(joinpath(base, simulations_dir, "basin_$basin_id.csv"), DataFrame)
            # additional clipping
            timeseries_df[:, "streamflow"] .= max.(coalesce.(simulation_df[end-n_lines+1:end, "sim"], NaN), 0.0)
            CSV.write(joinpath(base, timeseries_dir, "basin_$basin_id.csv"), timeseries_df)
        end

        # Update topological level for next iteration
        topo_lv -= 1
    end
end