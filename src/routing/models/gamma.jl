using DataFrames
using DSP
using SpecialFunctions

# Following mizuRoute v.1
# Should be used in hillslope routing

function γ(t::Real, a::Real, θ::Real)
    return (t^(a - 1) * exp(-t/θ)) / (θ^a * SpecialFunctions.gamma(a))
end

function dγdθ(t::Real, a::Real, θ::Real)
    num1 = t ^ (a - 1)
    num2 = -a*θ^(-a-1)*exp(-t/θ) + θ^(-a)*exp(-t/θ)/θ^2
    den = SpecialFunctions.gamma(a)
    return num1 * num2 / den
end

function dγda(t::Real, a::Real, θ::Real)
    num1 = θ^(-a) * t^(a-1) * exp(-t/θ)
    num2 = - SpecialFunctions.polygamma(0, a) - log(θ) + log(t)
    den = SpecialFunctions.gamma(a)
    return  num1 * num2 / den
end

function gamma(
    x::AbstractArray, 
    params::Vector{AbstractFloat},
    func::Function=γ,
    max_time::Int64=60,
)
    # Get paramaters from params
    a, θ = params[1], params[2]

    # Generate the function function values
    distribution = [func(t, a, θ) for t in 0:max_time-1]
    
    # Perform convolution
    streamflow = DSP.conv(x, distribution)[1:size(x)[1],:][:]

    return streamflow
end
