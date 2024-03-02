using Dates
using CSV
using DataFrames

include("../models/models.jl")
include("../models/gamma.jl")

function train_hillslope_routing(
    routing_lv_basins::Vector{Int},
    timeseries_dir::String,
    attributes_dir::String,
    start_date::Date, 
    end_date::Date,
    physical::AbstractPhysicalModel,
    learning_rate::Float64,
    epochs::Int,
) 
    error("Not sure it works.")
    
    # Define constants
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

        # Observed streamflow
        obs_streamflow = filtered_df[:,:streamflow]

        # Discard basins with NaN streamflow values on matched gauge dates
        if isnan(sum(obs_streamflow))
            continue
        end

        # Get area from HydroATLAS
        attributes_df = CSV.read(joinpath(attributes_dir, "attributes.csv"), DataFrame)
        basin_area = attributes_df[attributes_df.HYBAS_ID .== basin_id, :area][1]
        
        # Sum the runoff and sub-surface runoff columns
        runoff = (filtered_df[:,:sro_sum] .+ filtered_df[:,:ssro_sum])

        # Transform units
        runoff = runoff .* basin_area ./ day_to_s .* km²_to_m²

        # Concat
        x = hcat(x, runoff)
        y = hcat(y, obs_streamflow)
    end

    # Take out the initial zeros column
    x = x[:,2:end]
    y = y[:,2:end]

    # Train
    physical = train(
        x, 
        y, 
        physical, 
        learning_rate,
        epochs,
    )

    return physical
end

function simulate_hillslope_routing(
    routing_lv_basins::Vector{Int},
    timeseries_dir::String,
    attributes_dir::String,
    start_date::Date, 
    end_date::Date, 
    output_dir::String,
    physical::AbstractPhysicalModel,
)
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

        # Simulate
        streamflow = physical.model(runoff, physical.params)

        # Write output DataFrame
        output_df = DataFrame(date=dates, streamflow=streamflow)

        # Write streamflow timeseries
        CSV.write(joinpath(output_dir, "basin_$basin_id.csv"), output_df)
    end
end
