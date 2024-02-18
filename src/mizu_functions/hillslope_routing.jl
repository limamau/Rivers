using DataFrames
using SpecialFunctions

function gamma_function(x::AbstractArray{T}, a::Real, θ::Real) where T
    return (x .^ (a - 1) .* exp.(-x ./ θ)) ./ (θ ^ a * gamma(a))
end

function hillslope_route(timeseries_df::DataFrame, start_date::Date, end_date::Date, a::Real, θ::Real)
    # Filter the dataframe based on start_date and end_date
    filtered_df = filter(row -> start_date <= row[:time] <= end_date, timeseries_df)
    
    # Sum the runoff and sub-surface runoff columns
    filtered_df[!,:total_runoff] = filtered_df[:,:runoff] .+ filtered_df[:,:sub_surface_runoff]
    
    # Generate the gamma function
    time_range = 0:length(filtered_df[!,:total_runoff]) - 1
    gamma_values = gamma_function(time_range, a, θ)
    
    # Perform convolution
    streamflow_values = conv(filtered_df[!,:total_runoff], gamma_values, mode="full")
    
    # Create a new dataframe with streamflow values
    streamflow_df = DataFrame(streamflow = streamflow_values[1:end-length(gamma_values)+1],
                              time = filtered_df[!,:time])
    
    return streamflow_df
end

