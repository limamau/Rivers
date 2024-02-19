using DataFrames
using DSP
using SpecialFunctions

# Following mizuRoute v.1
# Should be used in hillslope routing

function gamma_distribution(t::Real, a::Real, θ::Real)
    return (t ^ (a - 1) .* exp(-t / θ)) / (θ ^ a * SpecialFunctions.gamma(a,0.))
end

# TODO: optimise this convolution
function gamma_conv(
    runoff::AbstractArray, 
    basin_area::Float64, 
    a::Real, 
    θ::Real, 
    max_time::Int64=60
)
    # Generate the gamma function values
    gamma_values = [gamma_distribution(t, a, θ) for t in 0:max_time-1]
    
    # Perform convolution
    day_to_s = 86400
    km²_to_m² = 1000000
    streamflow = DSP.conv(runoff, gamma_values)[1:length(runoff)] / day_to_s * basin_area * km²_to_m²

    return streamflow
end

