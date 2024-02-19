using CSV
using DataFrames
using Dates

include("../models/gamma.jl") # TODO: upload module

function hillslope_route(
    basin_id::Int64, 
    timeseries_dir::String,
    attributes_dir::String,
    start_date::Date, 
    end_date::Date, 
    method::String, 
    output_dir::String,
    a::Real, 
    θ::Real
)

    # Read DataFrame with inputs
    timeseries_df = CSV.read(joinpath(timeseries_dir, "basin_$basin_id.csv"), DataFrame)

    # Filter dates
    filtered_df = filter(row -> start_date <= row[:date] <= end_date, timeseries_df)

    # Get area from HydroATLAS
    attributes_df = CSV.read(joinpath(attributes_dir, "attributes.csv"), DataFrame)
    basin_area = attributes_df[attributes_df.HYBAS_ID .== basin_id, :SUB_AREA][1]
    
    # Sum the runoff and sub-surface runoff columns
    input = filtered_df[:,:sro_sum] .+ filtered_df[:,:ssro_sum]

    if method == "gamma"
        streamflow = gamma_conv(input, a, θ) .* basin_area
    # TODO: add the single-LSTM method
    # TODO: add the graph-LSTM method
    end

    # Get dates array
    dates = filtered_df.date

    # Write output DataFrame
    output_df = DataFrame(date=dates, streamflow=streamflow)

    # Write streamflow timeseries
    CSV.write(joinpath(output_dir, "basin_$basin_id.csv"), output_df)
end