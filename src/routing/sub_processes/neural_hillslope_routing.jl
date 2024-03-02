using CSV
using CUDA
using DataFrames
using Dates
using Flux
using ProgressMeter
using Statistics

include("../models/models.jl")
include("../models/LSTM.jl")

function get_arrays(timeseries_df::DataFrame, features::Int64)
    # Skipe dates and streamflow
    x = Matrix{Float32}(timeseries_df[:,2:features+1])

    # Normalisation of each features
    for i in 1:features
        mean_features = mean(x[:,i])
        std_features = std(x[:,i])
        x[:,i] = (x[:,i] .- mean_features) ./ std_features
    end
    
    # Only streamflow
    y = (timeseries_df[:,end])
    y = reshape(y, (length(y),1))

    return x, y
end

function forecast_last(m::Chain, x::AbstractArray, seq_length::Int64)
    # Forget previous batches
    Flux.reset!(m)

    # Store hidden state but ignore output
    for i in 1 : seq_length-1
        m(x[i,:])
    end
    return m(x[end,:])
end

function predict(m::Chain, x::AbstractArray, seq_length::Int64)
    return vcat([forecast_last(m, x[i:seq_length+i-1,:], seq_length) for i in 1:size(x,1)-seq_length+1]...)
end

function basin_loss(m::Chain, x::AbstractArray, y::AbstractArray, seq_length::Int64)
    println(typeof(y))
    println(size(y[seq_length:end,1]))
    println(size(predict(m, x, seq_length)))
    nums = (y[seq_length:end] .- predict(m, x, seq_length)).^2
    den = (std(y[seq_length:end]) - mean(y)).^2
    return sum(nums / den)
end

function nse_loss(m::Chain, xb::AbstractArray, yb::AbstractArray, seq_length::Int64)
    nse_loss_sum = 0.0
    for (x, y) in zip(xb, yb)
        nse_loss_sum += basin_loss(m, x, y, seq_length)
    end
    return 1 / length(xb) * nse_loss_sum
end

function train_hillslope_routing(
    routing_lv_basins::Vector{Int64},
    timeseries_dir::String,
    attributes_dir::String,
    start_date::Date,
    end_date::Date,
    neural::AbstractNeuralModel,
    learning_rate::Float64,
    epochs::Int64,
)
    # Get arrays
    xb, yb = Matrix{Float32}[], Matrix{Float32}[]

    # Iterate over basins in the given routing level
    for (idx, basin_id) in enumerate(routing_lv_basins)
        # Read DataFrame with inputs
        timeseries_df = CSV.read(joinpath(timeseries_dir, "basin_$basin_id.csv"), DataFrame)

        # Filter dates
        filtered_df = filter(row -> start_date <= row[:date] <= end_date, timeseries_df)

        # Observed streamflow
        obs_streamflow = filtered_df[:,:streamflow]

        # Discard basins with NaN streamflow values on matched gauge dates
        if isnan(sum(obs_streamflow))
            continue
        end

        # Get area from HydroATLAS
        attributes_df = CSV.read(joinpath(attributes_dir, "attributes.csv"), DataFrame)
        basin_area = Float32(attributes_df[attributes_df.HYBAS_ID .== basin_id, :area][1])

        # Load data from basin file
        features = 3 # TODO: pass this as a parameter
        timeseries_df = timeseries_df[:, ["sro_sum", "ssro_sum", "t2m_mean", "streamflow"]]

        # Just to test
        x, y = get_arrays(timeseries_df, features)
        push!(xb, x)
        push!(yb, y)
    end

    # Take mean and std of the ensemble
    mean_q = mean([mean(y) for y in yb])
    std_q = sum(sum([(y.-mean_q).^2 for y in yb])) / (length(yb)*length(yb[1])-1)

    # Normalisation
    for i in 1length(yb)
        yb[i] = (yb[i] .- mean_q) ./ std_q
    end

    # Pass data to gpu
    xb, yb = (xb, yb) |> gpu
    
    # TODO: pass this as a parameter
    seq_length = 270
    optim = Flux.setup(Adam(learning_rate), neural.model)

    # Training loop
    println("Training...")
    for epoch in 1:epochs
        # Gradient context
        loss, grads = Flux.withgradient(neural.model) do m
            @time nse_loss(m, xb, yb, seq_length)
        end
        
        println("epoch: $epoch - loss: $loss")

        # Update model
        Flux.update!(optim, neural.model, grads[1])
    end

    return neural
end

function simulate_hillslope_routing(
    routing_lv_basins::Vector{Int64},
    timeseries_dir::String,
    attributes_dir::String,
    start_date::Date, 
    end_date::Date, 
    output_dir::String,
    neural::AbstractNeuralModel,
)
    # TODO: finish this
    # Define constants
    day_to_s = 86400
    km²_to_m² = 1000000

    # Get the array of dates
    dates = collect(start_date : Day(1) : end_date)

    # Read attributes as DataFrame
    attributes_df = CSV.read(joinpath(attributes_dir, "attributes.csv"), DataFrame)

    # Write results
    first = true
    for basin_id in routing_lv_basins
        # Read DataFrame with inputs
        timeseries_df = CSV.read(joinpath(timeseries_dir, "basin_$basin_id.csv"), DataFrame)

        # Filter dates
        filtered_df = filter(row -> start_date <= row[:date] <= end_date, timeseries_df)

        # Get area from HydroATLAS
        basin_area = attributes_df[attributes_df.HYBAS_ID .== basin_id, :area][1]

        # Sum the runoff and sub-surface runoff columns and transform units
        runoff = (filtered_df[:,:sro_sum] .+ filtered_df[:,:ssro_sum])
        runoff = runoff .* basin_area ./ day_to_s .* km²_to_m²

        streamflow = model(Flux.normalise(Float32.(runoff)))[:]

        # Write output DataFrame
        output_df = DataFrame(date=dates, streamflow=streamflow[:])

        # Write streamflow timeseries
        CSV.write(joinpath(output_dir, "basin_$basin_id.csv"), output_df)
    end
    # TODO: pass this as a parameter
    seq_length = 270

    # TODO: write this in the csvs
    y_hat = (predict(neural, xb[1], seq_length) .+ mean_q) .*std_q

    return neural
end