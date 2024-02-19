using DataFrames
using SpecialFunctions

# Following mizuRoute v.1
# Should be used in river channel routing

function h_distribution(x::Real, t::Real, C::Real, D::Real)
    return x / (2 * t * sqrt(π * D * t)) * exp(-((C * t - x) / (4 * D * t)))
end

function IRF(up_streamflow::AbstractArray, x::Real, C::Real, D::Real, max_time::Int64=60)
    # Generate the h(x,t) function values
    day_s = 86400
    km_to_m = 1000
    h_values = [h_distribution(x*km_to_m, t*day_s, C, D) for t in 0:max_time-1]
    
    # Perform convolution
    streamflow = DSP.conv(up_streamflow, h_values)[1:length(up_streamflow)]
    
    return streamflow
end

