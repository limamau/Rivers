using Statistics
include("../models/gamma.jl")
include("../models/IRF.jl")

# NSE loss function
function L(model, x, y, params, ϵ=1e-3)
    ŷ = model(x, params[1], params[2])
    num = (ŷ .- y).^2
    den = (std(y, dims=1) .+ ϵ).^2 .* size(x)[2]
    return sum(num ./ den)
end

function dLdθ(model, x, y, a, θ, ϵ=1e-3)
    ŷ = model(x, a, θ)
    num = 2 * (ŷ .- y) .* model(x, a, θ, dγdθ)
    den = (std(y, dims=1) .+ ϵ).^2 .* size(x)[2]
    return  sum(num ./ den)
end

function dLda(model, x, y, a, θ, ϵ=1e-3)
    ŷ = model(x, a, θ)
    num = 2 * (ŷ .- y) .* model(x, a, θ, dγda)
    den = (std(y, dims=1) .+ ϵ).^2 .* size(x)[2]
    return  sum(num ./ den)
end

function dLdC(model, x, y, C, D, ϵ=1e-3) 
    ŷ = model(x, C, D)
    num = 2 * (ŷ .- y) .* model(x, C, D, dhdC)
    den = (std(y, dims=1) .+ ϵ).^2 .* size(x)[2]
    return  sum(num ./ den)
end

function dLdD(model, x, y, C, D, ϵ=1e-3)
    ŷ = model(x, C, D)
    num = 2 * (ŷ .- y) .* model(x, C, D, dhdD)
    den = (std(y, dims=1) .+ ϵ).^2 .* size(x)[2]
    return sum(num ./ den)
end

# As we're not normalizing the data, 
# I am calculating the order of magnitude of the parameters
# TODO: improve this method
function order_of_magnitude(x)
    return 10^floor(log10(abs(x)))
end

function train(
    x::Array{Float64},
    y::Array{Float64}, 
    method::String, 
    params::Vector{Real},
    learning_rate::Real,
    iterations::Int64,
)
    # Select the method
    if method == "gamma"
        dLdparams = (dLda, dLdθ)
        model = gamma
        println("Initial parameters: a = $(params[1]), θ = $(params[2])")
    elseif method == "IRF"
        dLdparams = (dLdC, dLdD)
        model = IRF
        println("Initial parameters: C = $(params[1]), D = $(params[2])")
    else
        error("Unknown method: $method")
    end

    # Loss before the training
    loss_value = L(model, x, y, params)
    println("iter 0: $loss_value")

    # Training iterations
    for i in 1:iterations
        # Calculate gradients
        grad1 = dLdparams[1](model, x, y, params...)
        grad2 = dLdparams[2](model, x, y, params...)
        
        # Update parameters if gradients are not NaN
        if !isnan(grad1)
            params[1] -= learning_rate * grad1 * order_of_magnitude(params[1])
        else
            println("Gradient 1 is NaN")
        end
        if !isnan(grad2)
            params[2] -= learning_rate * grad2 * order_of_magnitude(params[2])
        else
            println("Gradient 2 is NaN")
        end
        
        # Print loss value
        loss_value = L(model, x, y, params)
        println("iter $i: $loss_value")
    end

    # Print trained parameters
    if method == "gamma"
        println("Trained parameters: a = $(params[1]), θ = $(params[2])")
    elseif method == "IRF"
        println("Trained parameters: C = $(params[1]), D = $(params[2])")
    end

    return params
end