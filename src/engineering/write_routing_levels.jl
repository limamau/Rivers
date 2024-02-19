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

    # Iterator for the routing levels
    # We begin with source basins
    routing_lv = 1

    # Array to store the basins in the curre
    routing_lv_basins = Int64[]

    # Get the the source basins
    print("Source basins... ")
    for basin_id in keys(graph_dict)
        if isempty(graph_dict[basin_id])
            push!(routing_lv_basins, parse(Int64, basin_id))
        end
    end

    # Create output directory
    mkpath(output_dir)

    # Write source basins in output directory
    write_routing_level(routing_lv_basins, routing_lv, output_dir)
    println("Done!")

    # Upload routing level
    routing_lv += 1

    # Iterate over the other levels
    print("Routing basins... ")
    while !isempty(routing_lv_basins)
        # Upload routing level
        routing_lv += 1

        # Repopulate routing_lv_basins
        aux_array = Int64[]
        for basin_id in routing_lv_basins
            # Check if downstream exists in the graph
            next_down_id = hydro_df[hydro_df.HYBAS_ID .== basin_id, :NEXT_DOWN][1]
            if next_down_id != 0
                push!(aux_array, next_down_id)
            end
        end
        routing_lv_basins = aux_array

        write_routing_level(routing_lv_basins, routing_lv, output_dir)
    end

    # Remove unecessary directory
    rm(joinpath(output_dir, "routing_lv"*lpad(routing_lv, 2, "0")*".txt"))

    println("Done!")
end