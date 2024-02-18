using DataFrames
using SpecialFunctions

function h(x::Real, t::Real, C::Real, D::Real)
    return x / (2 * t * sqrt(π * D * t)) * exp(-((C * t - x) / (4 * D * t)))
end

function IRF(streamflow_df::DataFrame, start_date::Date, end_date::Date, a::Real, θ::Real, x::Real, C::Real, D::Real)
    # Filter the dataframe based on start_date and end_date
    filtered_df = filter(row -> start_date <= row[:date] <= end_date, streamflow_df)
    
    # Generate the h(x,t) function
    time_range = 0:length(filtered_df[!,:streamflow]) - 1
    h_values = [h(x, t, C, D) for t in time_range]
    
    # Perform convolution
    routed_streamflows = conv(filtered_df[!,:streamflow], h_values)
    
    # Create a new dataframe with routed streamflow values
    routed_streamflow_df = DataFrame(streamflow = routed_streamflow_values[1:end-length(h_values)+1],
                                     date = filtered_df[!,:date])
    
    return routed_streamflow_df
end

