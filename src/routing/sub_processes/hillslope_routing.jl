using Dates

include("physical_hillslope_routing.jl")
include("neural_hillslope_routing.jl")

# Main
function hillslope_route(
    routing_lv_basins::Vector{Int64},
    timeseries_dir::String,
    attributes_dir::String,
    start_date::Date, 
    end_date::Date, 
    output_dir::String,
    model::AbstractModel,
    is_training::Bool,
    learning_rate::Real=nothing,
    epochs::Int64=nothing,
)
    if is_training
    model = train_hillslope_routing(
            routing_lv_basins,
            timeseries_dir,
            attributes_dir,
            start_date, 
            end_date, 
            model,
            learning_rate,
            epochs,
        )
    end
    
    simulate_hillslope_routing(
        routing_lv_basins,
        timeseries_dir,
        attributes_dir,
        start_date, 
        end_date, 
        output_dir,
        model,
    )

    return model
end