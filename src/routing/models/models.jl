# using Flux

abstract type AbstractModel end

struct AbstractPhysicalModel <: AbstractModel
    model::Function
    params::Vector{AbstractFloat}
end

# struct AbstractNeuralModel <: AbstractModel
#    model::Chain
# end
