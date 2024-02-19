using CSV
using DataFrames
using Dates

include("../models/IRF.jl") # TODO: upload module

function river_channel_route(
    basin_id::Int64,
    up_basin::Int64,
    attributes_dir::String,
    method::String,
    output_dir::String,
    C::Real, 
    D::Real
)

    # Read DataFrame with inputs from upstream
    timeseries_df = CSV.read(joinpath(output_dir, "basin_$basin_id.csv"), DataFrame)

    # Get basin area and the riverine distance (x) from HydroATLAS
    attributes_df = CSV.read(joinpath(attributes_dir, "attributes.csv"), DataFrame)
    x = attributes_df[attributes_df.HYBAS_ID .== basin_id, :DIST_MAIN][1] - attributes_df[attributes_df.HYBAS_ID .== up_basin, :DIST_MAIN][1]
    
    # Sum the runoff and sub-surface runoff columns
    input = timeseries_df[:,:streamflow]

    if method == "IRF"
        streamflow = IRF(input, x, C, D)
    # TODO: add the single-LSTM method
    # TODO: add the graph-LSTM method
    end

    # Get dates array
    dates = timeseries_df.date

    # Write output DataFrame
    output_df = DataFrame(date=dates, streamflow=streamflow)

    # Write streamflow timeseries
    CSV.write(joinpath(output_dir, "basin_$basin_id.csv"), output_df) # this will override the file
end