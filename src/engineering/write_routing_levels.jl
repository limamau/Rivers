using CSV
using DataFrames
using JSON
using ProgressMeter
using Shapefile
using Statistics

function write_routing_level(routing_lv_basins::Array{Int64}, routing_lv::Int64, output_dir::String)
    # Define file name
    file_name = joinpath(output_dir, "routing_lv"*lpad(routing_lv, 2, "0")*".txt")
        
    # Open the file in write mode
    file = open(file_name, "w")
    
    # Write list of all basin in the same routing level
    for basin_id in routing_lv_basins
        write(file, "$basin_id\n")
    end

    # Close file
    close(file)
end

function write_routing_levels(graph_dict_file::String, hydroatlas_shp_file::String, output_dir::String)
    # Read graph
    graph_dict = JSON.parsefile(graph_dict_file)

    # Read HydroATLAS shapefile as a DataFrame
    hydro_df = Shapefile.Table(hydroatlas_shp_file) |> DataFrame

    # We begin with source basins
    routing_lv = 1

    # Array to store the basins in the current level
    routing_lv_basins = Int64[]

    # Sets to store written and unwrittens basins
    written_basins = Set{Int64}()
    unwritten_basins = Set{Int64}()

    # Get the the source basins
    print("Source basins... ")
    for basin_id in hydro_df[:,:HYBAS_ID]
        if isempty(graph_dict[string(basin_id)])
            push!(routing_lv_basins, basin_id)
            push!(written_basins, basin_id)
        else
            push!(unwritten_basins, basin_id)
        end
    end

    # Create output directory
    if isdir(output_dir)
        println("\nDeleting old routing levels...")
        rm(output_dir, recursive=true)
    end
    mkpath(output_dir)

    # Write source basins in output directory
    write_routing_level(routing_lv_basins, routing_lv, output_dir)
    println("Done!")

    # Iterate over the other levels
    print("Routing basins... ")
    while !isempty(unwritten_basins)
        # Upload routing level
        routing_lv += 1

        # Repopulate routing_lv_basins
        routing_lv_basins = Int64[]
        for basin_id in unwritten_basins
            # Check if upstreams are all written
            all_up_written = true
            for up_basin in graph_dict[string(basin_id)]
                if !(up_basin in written_basins)
                    all_up_written = false
                end
            end
            if all_up_written
                push!(routing_lv_basins, basin_id)
                push!(written_basins, pop!(unwritten_basins, basin_id))
            end
        end

        # Write routing level
        write_routing_level(routing_lv_basins, routing_lv, output_dir)
    end

    # Remove unecessary directory
    rm(joinpath(output_dir, "routing_lv"*lpad(routing_lv, 2, "0")*".txt"))

    println("Done!")
end