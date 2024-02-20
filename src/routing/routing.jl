using JSON

include("hillslope_routing.jl") # TODO: write this usinig modules
include("river_channel_routing.jl") # TODO write this using modules

# Auxiliar function
function read_routing_lv_basins(routing_lv_file::String)
    routing_lv_basins = Int64[]
    file = open(joinpath(routing_lv_file))
        for line in eachline(file)
            push!(routing_lv_basins, parse(Int64, line))
        end
    close(file)

    return routing_lv_basins
end

# Auxiliar function
function create_simulation_dir(output_dir::String)
    if isdir(output_dir)
        println("Deleting old simulations...")
        rm(output_dir, recursive=true)
    end

    mkpath(output_dir)
end

# Main
function route(
    timeseries_dir::String,
    attributes_dir::String,
    graph_dict_file::String,
    routing_levels_dir::String,
    hillslope_method::String,
    river_channel_method::String,
    start_date::Date,
    end_date::Date,
    output_dir::String
)
    # Definition of parameters as in mizuRouting v.1 but re-scaled
    # TODO: optimize it
    a = 1.5 # Shape factor (adjusted)
    θ = 1 # Timescale factor [day]
    C = 1.5 * 86400 # Wave velocity [m/day]
    D = 8000 * 86400 # Diffusivity [m²/day] (adjusted)

    # Read JSON file as a dictionary
    graph_dict = JSON.parsefile(graph_dict_file)

    # Define starting routing level
    routing_lv = 1

    # Create simulation directory
    create_simulation_dir(output_dir)

    # Iterate over routing levels
    for routing_lv_file in readdir(routing_levels_dir, join=true)
        println("Routing lv"*lpad(routing_lv, 2, "0")*"... ")
        
        # Get basins in the current routing level
        routing_lv_basins = read_routing_lv_basins(routing_lv_file)
        
        # Iterate over the basins
        for basin_id in routing_lv_basins
            # Hillslope routing
            hillslope_route(
                basin_id, 
                timeseries_dir,
                attributes_dir,
                start_date, 
                end_date, 
                hillslope_method, 
                output_dir,
                a, θ, # params
            ) 

            # No river channel routing for source basins
            if routing_lv != 1

                # River channel routing
                for up_basin in graph_dict[string(basin_id)]
                    river_channel_route(
                        basin_id,
                        up_basin,
                        attributes_dir,
                        river_channel_method, 
                        output_dir, 
                        C, D, # params
                    )
                end
            end
        end
        
        # Upload routing level
        routing_lv += 1
    end
end
