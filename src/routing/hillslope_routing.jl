using CSV
using DataFrames
using Dates

include("../models/gamma.jl") # TODO: upload module
include("train.jl")

function hillslope_route(
    routing_lv_basins::Array{Int64},
    timeseries_dir::String,
    attributes_dir::String,
    start_date::Date, 
    end_date::Date, 
    method::String, 
    is_training::Bool,
    output_dir::String,
    a::Real, 
    θ::Real,
    learning_rate::Real=nothing,
    epochs::Int64=nothing,
) 
    # First column boolean
    day_to_s = 86400
    km²_to_m² = 1000000

    # Allocate x and y
    time_length = (end_date - start_date).value + 1
    x = zeros(time_length)
    y = zeros(time_length)

    # Allocate not-NaN indexes
    valid_idxs = Int64[]

    # Allocate basin IDs
    basin_ids = Int64[]

    # Iterate over basins in the given routing level
    for (idx, basin_id) in enumerate(routing_lv_basins)
        # Read DataFrame with inputs
        timeseries_df = CSV.read(joinpath(timeseries_dir, "basin_$basin_id.csv"), DataFrame)

        # Filter dates
        filtered_df = filter(row -> start_date <= row[:date] <= end_date, timeseries_df)

        # Get area from HydroATLAS
        attributes_df = CSV.read(joinpath(attributes_dir, "attributes.csv"), DataFrame)
        basin_area = attributes_df[attributes_df.HYBAS_ID .== basin_id, :area][1]
        
        # Sum the runoff and sub-surface runoff columns
        runoff = (filtered_df[:,:sro_sum] .+ filtered_df[:,:ssro_sum])

        # Transform units
        runoff = runoff .* basin_area ./ day_to_s .* km²_to_m²

        # Streamflow
        streamflow = filtered_df[:,:streamflow]

        # Ignore ungauged basins if not training
        if is_training
            if !isnan(sum(streamflow))
                push!(valid_idxs, idx)
            end
        end

        # Concat
        x = hcat(x, runoff)
        y = hcat(y, streamflow)

        # Push basin ID
        push!(basin_ids, basin_id)
    end

    # Take out the initial zeros column
    x = x[:,2:end]
    y = y[:,2:end]

    # Select model
    if method == "gamma"
        model = gamma
    end

    # Train
    if is_training
        a, θ = train(
            x[:,valid_idxs], 
            y[:,valid_idxs], 
            method, 
            Real[a, θ],
            learning_rate,
            epochs,
        )
    end

    # Get the array of dates
    dates = collect(start_date : Day(1) : end_date)

    # Predict
    ŷ = model(x, a, θ)

    # Write results
    for (idx, basin_id) in enumerate(basin_ids)
        # Get streamflow
        streamflow = ŷ[:,idx]

        # Write output DataFrame
        output_df = DataFrame(date=dates, streamflow=streamflow)

        # Write streamflow timeseries
        CSV.write(joinpath(output_dir, "basin_$basin_id.csv"), output_df)
    end

    return a, θ
end