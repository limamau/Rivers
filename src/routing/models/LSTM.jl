using Flux

function LSTM(features::Int64, hidden_size::Int64, output::Int64)::Chain
    Chain(
        Flux.LSTM(features, hidden_size),
        Dense(hidden_size, output)
    ) |> gpu
end
