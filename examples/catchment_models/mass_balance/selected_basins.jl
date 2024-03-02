using CSV
using DataFrames
using ProgressMeter

include("utils.jl")

# This code uses selected_basins.txt which is in the analysis/ folder.

function plot_histogram(diffs::Vector{Float64}, threshold::Real, n_outliers::Int)
    # Define figure and axis
    fig = Figure()
    ax = Axis(fig[1,1], title="(P-E) - (Rs+Rss)", ylabel="N of basins", xlabel="mm/yr")

    # Plot histogram
    hist!(ax, diffs, bins=100)
    text!(-threshold+0.1, 50, text="N of outliers: $n_outliers")

    # Save figure
    save("mass_balance/png_files/selected_basins_histogram.png", fig)
end

# Start run here
let
    # Empty array to store values to plot in the histogram
    histogram_diffs::Vector{Float64} = Float64[]

    # Define constant
    m_to_mm = 1000

    # Define threshold for n_outliers
    threshold = 200
    n_outliers = 0

    # Read used basins from the folder
    selected_basins = Int[]
    file_path = "examples/catchment_model/analysis/selected_basins.txt" 
    open(file_path) do file
        for line in eachline(file)
            push!(selected_basins, parse(Int, line))
        end
    end

    # Iterate over HydroSHEDS levels
    msg =  "Iterating over basins..."
    @showprogress msg for basin_id in selected_basins
        # Read level from basin ID
        lv = string(basin_id)[2:3]
        
        # Directories with lv information
        xd_dir = "/central/scratch/mdemoura/Rivers/midway_data/xd_lv$lv"
        xd_evaporation_dir = "/central/scratch/mdemoura/Rivers/midway_data/xd_lv$lv"*"_evaporation"

        # Take length of generic file in the evaporation folder
        file = "basin_$basin_id.csv"

        # Vector to save differences and basin ID
        diffs::Vector{Float64} = Float64[]
        basins::Vector{Int64} = Int64[]

        # Total differences
        total_p_minus_e_sum = 0
        total_runoff_sum = 0
        
        df = CSV.read(joinpath(xd_dir, file), DataFrame)
        e_df = CSV.read(joinpath(xd_evaporation_dir, file), DataFrame)

        time_length = length(e_df[:,1])
        # Check dimensions of evaporation DataFrame
        if length(e_df[:,1]) != time_length
            println("\nError in dimensions of ", basin_id)
            continue
        end

        # Proceed normaly
        p_minus_e_sum = sum(df[1:time_length, "tp_sum"]) + sum(e_df[1:time_length, "e_sum"])
        runoff_sum = sum(df[1:time_length, "sro_sum"]) + sum(df[1:time_length, "ssro_sum"])

        diff = (p_minus_e_sum - runoff_sum) * m_to_mm / 10 # TODO: solve hard coding
        push!(diffs, diff)
        push!(basins, basin_id)

        if abs(diff) < threshold
            total_p_minus_e_sum += p_minus_e_sum
            total_runoff_sum += runoff_sum
        else
            n_outliers += 1
        end

        # Append into the histogram array
        append!(histogram_diffs, [x for x in diffs if abs(x) <= threshold])
    end

    # Plot histogram
    plot_histogram(histogram_diffs, threshold, n_outliers)
end