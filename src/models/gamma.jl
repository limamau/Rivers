using DataFrames
using DSP
using SpecialFunctions

# Following mizuRoute v.1
# Should be used in hillslope routing

function gamma_distribution(t::Real, a::Real, θ::Real)
    return (t ^ (a - 1) .* exp(-t / θ)) / (θ ^ a * SpecialFunctions.gamma(a,0.))
end

# TODO: optimise this convolution
function gamma_conv(runoff::AbstractArray, a::Real, θ::Real, max_time::Int64=60)
    # Generate the gamma function values
    day_s = 86400
    gamma_values = [gamma_distribution(t*day_s, a, θ) for t in 0:max_time-1]
    
    # Perform convolution
    streamflow = DSP.conv(runoff, gamma_values)[1:length(runoff)]
    
    return streamflow
end

