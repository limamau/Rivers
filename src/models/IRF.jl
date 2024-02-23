using DataFrames
using DSP

# Following mizuRoute v.1
# Should be used in river channel routing

function h(x::Real, t::Real, C::Real, D::Real)
    return x / (2*t * sqrt(π*D*t)) * exp(-((C*t - x)^2 / (4*D*t)))
end

function dhdC(x::Real, t::Real, C::Real, D::Real)
    num1 = -x * (C*t - x)
    num2 = exp(-(C*t - x)^2 / (4*D*t))
    den = 4*D*t * sqrt(π*D*t)
    return num1 * num2 / den
end

function dhdD(x::Real, t::Real, C::Real, D::Real)
    numexp = exp(-(C*t - x)^2 / (4*D*t))
    num1 = x * (C*t - x)^2
    den1 = 8 * (D*t)^2 * sqrt(π*D*t)
    num2 = x
    den2 = 4*D*t * sqrt(π*D*t)
    return num1 * numexp / den1 - num2 * numexp / den2
end

function IRF(
    x::AbstractArray,
    C::Real, 
    D::Real,
    func::Function=h, 
    max_time::Int64=120,
)
    # De-concatenate x into up_q and x
    up_q = x[1:end-1,:]
    dist = x[end,:]

    # Allocate streamflow array
    streamflow = similar(up_q)

    for i in 1:size(up_q)[2]
        # Generate the h(dist,t) function values
        distribution = [func(dist[i], t, C, D) for t in 1:max_time]
        
        # Perform convolution
        streamflow[:,i] = DSP.conv(up_q[:,i], distribution)[1:size(up_q)[1]]
    end
    
    return streamflow
end

