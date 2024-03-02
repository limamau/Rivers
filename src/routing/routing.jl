using JSON

# TODO write this using modules
include("sub_processes/hillslope_routing.jl")
include("sub_processes/physical_hillslope_routing.jl")
include("sub_processes/neural_hillslope_routing.jl")
include("sub_processes/river_channel_routing.jl")
include("models/models.jl")
include("models/gamma.jl")
include("models/LSTM.jl")
include("models/IRF.jl")

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
    train_hillslope::Bool,
    river_channel_method::String,
    train_river_channel::Bool,
    start_date::Date,
    end_date::Date,
    output_dir::String,
    hillslope_epochs::Int64=nothing,
    hillslope_learning_rate::Float64=nothing,
    river_channel_epochs::Int64=nothing,
    river_channel_learning_rate::Float64=nothing,
)
    # Definition of initial parameters as in mizuRouting v.1 but re-scaled
    a = 1.5 # Shape factor (adjusted)
    θ = 1 # Timescale factor [day]
    C = 1.5 * 86400 # Wave velocity [m/day]
    D = 8000 * 86400 # Diffusivity [m²/day] (adjusted)

    # Define initial parameters for hillslope routing
    if hillslope_method == "gamma"
        hillslope_model = AbstractPhysicalModel(gamma, [a, θ])
    
    elseif hillslope_method == "LSTM"
        # TODO: pass LSTM parameters as parameters in the routing function
        features = 3
        hidden_size = 8
        output = 1
        hillslope_model = AbstractNeuralModel(LSTM(features, hidden_size, output))
    
    else
        error("Method not implemented.")
    end

    # Define initial parameters for river channel routing
    if river_channel_method == "IRF"
        river_channel_model = AbstractPhysicalModel(IRF, [C, D])

    else
        error("Method not implemented.")
    end

    # Read JSON file as a dictionary
    graph_dict = JSON.parsefile(graph_dict_file)

    # Create simulation directory
    create_simulation_dir(output_dir)
    

    # Hillslope routing
    println("Hillslope routing...")
    
    # Define starting routing level
    routing_lv = 1

    # Iterate over routing levels
    for routing_lv_file in readdir(routing_levels_dir, join=true)
        println("Routing lv"*lpad(routing_lv, 2, "0")*"... ")
    
        # Get basins in the current routing level
        routing_lv_basins = read_routing_lv_basins(routing_lv_file)
        
        # Hillslope routing
        hillslope_params =  hillslope_route(
            routing_lv_basins,
            timeseries_dir,
            attributes_dir,
            start_date, 
            end_date, 
            output_dir,
            hillslope_model,
            train_hillslope,
            hillslope_learning_rate,
            hillslope_epochs,
        )

        # Don't train hillslope routing for descendent basins
        if routing_lv == 1
            train_hillslope = false
        end
    
        # Upload routing level
        routing_lv += 1
    end

    
    # River Channel Routing
    println("River channel routing...")

    # Define starting routing level (no river channel routing for source basins)
    routing_lv = 2

    # Iterate over routing levels
    for routing_lv_file in readdir(routing_levels_dir, join=true)[2:end]
        println("Routing lv"*lpad(routing_lv, 2, "0")*"... ")

        # Get basins in the current routing level
        routing_lv_basins = read_routing_lv_basins(routing_lv_file)
        
        # River channel routing
        river_channel_params = river_channel_route(
            routing_lv_basins,
            graph_dict,
            timeseries_dir,
            attributes_dir,
            output_dir, 
            river_channel_model,
            train_river_channel,
            river_channel_learning_rate,
            river_channel_epochs,
        )

        # Upload routing level
        routing_lv += 1
    end
end
