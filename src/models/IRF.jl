using DataFrames
using SpecialFunctions

# Following mizuRoute v.1
# Should be used in river channel routing

function h_distribution(x::Real, t::Real, C::Real, D::Real)
    return x / (2 * t * sqrt(π * D * t)) * exp(-((C * t - x)^2 / (4 * D * t)))
end

function IRF(up_streamflow::AbstractArray, x::Real, C::Real, D::Real, max_time::Int64=120)
    # Generate the h(x,t) function values
    km_to_m = 1000
    h_values = [h_distribution(x*km_to_m, t, C, D) for t in 1:max_time]
    
    # Perform convolution
    streamflow = DSP.conv(up_streamflow, h_values)[1:length(up_streamflow)]

    # println(x)
    # println(h_values)
    # error("a")
    
    return streamflow
end

