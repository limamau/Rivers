using CairoMakie
using ColorSchemes
using CSV
using DataFrames
using Dates
using Statistics

function scatter_to_heatmap(x, y, x_min, x_max, y_min, y_max, n_bins::Tuple{Int,Int}=(50,50))
    # Constrain x and y within specified ranges
    x = clamp.(x, x_min, x_max)
    y = clamp.(y, y_min, y_max)

    # Calculate grid bounds
    x_bins = range(x_min, stop=x_max, length=n_bins[1])
    y_bins = range(y_min, stop=y_max, length=n_bins[2])

    # Initialize counts
    counts = zeros(Int, n_bins)

    # Assign points to bins
    for i in eachindex(x)
        x_index = argmin(abs.(x[i] .- x_bins))
        y_index = argmin(abs.(y[i] .- y_bins))
        counts[x_index, y_index] += 1
    end

    # Normalize counts to get densities
    densities = counts 

    return x_bins, y_bins, densities
end

function main()
    # Read scores as a DataFrame
    base = "/central/scratch/mdemoura/Rivers"
    csv_file = "examples/catchment_models/analysis/csv_files/globe_all_daily.csv"
    scores_df = CSV.read(csv_file, DataFrame)

    # Read attributes in each of the three levels
    first = true
    attributes_df = DataFrame()
    for hydro_lv in ["05", "06", "07"]
        hydroatlas_attributes_df = CSV.read(joinpath(base, "single_model_data/attributes/attributes_lv$hydro_lv/hydroatlas_attributes.csv"), DataFrame)
        if first
            attributes_df = hydroatlas_attributes_df
            first = false
        else
            attributes_df = vcat(attributes_df, hydroatlas_attributes_df)
        end
    end

    # Merge scores and attributes into one DataFrame
    merged_df = innerjoin(scores_df, attributes_df, on=:basin=>:basin_id)

    # State plotting arrays
    nse_arr = Float64[]
    aridity_arr = Float64[]
    irrigation_arr = Int64[]
    runoff_arr = Int64[]

    # Basin in Figure 6a
    fig6a_basin_id = 1061638580

    # Iterate over all basins
    for row in eachrow(merged_df)
        # Get basin ID and NSE score
        basin_id = row[:basin]
        basin_nse = row[:nse]
        basin_aridity = row[:ari_ix_sav] / 100
        basin_irrigation = row[:ire_pc_sse]
        basin_runoff = row[:run_mm_syr]

        # Append to plotting arrays
        push!(nse_arr, basin_nse)
        push!(aridity_arr, basin_aridity)
        push!(irrigation_arr, basin_irrigation)
        push!(runoff_arr, basin_runoff)
        
        # Print aridity index of the basin in Fig06a
        if basin_id == fig6a_basin_id
            println("aridity index: ", basin_aridity)
        end
    end

    # Define colormap
    cm = cgrad([:white, :orange, :brown], [0.2, 0.7])

    # Aridity
    fig = Figure(resolution=(500,400))
    x_min, x_max = -1, 1
    y_min, y_max = 0, 4
    ax = Axis(
        fig[1,1],
        xlabel="NSE",
        xlabelsize=17,
        ylabel="Aridity index",
        ylabelsize=17,
        limits=(x_min, x_max, y_min, y_max),
    )
    
    # Get bins and densities for heatmap
    x_bins, y_bins, densities = scatter_to_heatmap(nse_arr, aridity_arr, x_min, x_max, y_min, y_max)
    
    # Plot heatmap
    hm = heatmap!(ax, x_bins, y_bins, densities, colormap=cm)
    Colorbar(fig[1,2], hm, label="Number of basins", labelsize=17)
    
    # Save
    save("examples/catchment_models/analysis/png_files/nse_vs_aridity.png", fig, px_per_unit=4)
end

main()