using CairoMakie
using CSV
using DataFrames
using Dates
using Statistics

let 
    # Define basin
    basin_id = 2070510690
    ddf = CSV.read("/central/scratch/mdemoura/data/timeseries/timeseries_lv07/basin_$basin_id.csv", DataFrame)
    transform!(ddf, :date => ByRow(yearmonth) => :month)
    mdf = combine(groupby(ddf, :month), :sro_sum => sum => :sro_sum, 
                                        :ssro_sum => sum => :ssro_sum, 
                                        :streamflow => sum => :streamflow)

    sdf = CSV.read("/central/scratch/mdemoura/data/attributes/attributes_lv07/other_attributes.csv", DataFrame)
    basin_area = sdf[sdf[:, :basin_id] .== basin_id, "area"]

    # Select date indexes
    min_date_idx = findfirst(date -> date == Date(1995, 01, 01), ddf[:, "date"])
    max_date_idx = findfirst(date -> date == Date(1996, 12, 31), ddf[:, "date"])

    # Plot - Daily
    fig = Figure()
    ax = Axis(fig[1,1], ylabel="m^3/day")
    lines!(ax, min_date_idx:max_date_idx, ddf[min_date_idx:max_date_idx, "sro_sum"] .* (basin_area*1000000),label="Surface Runoff", transparency=true, color=:orchid, linewidth = 2)
    lines!(ax, min_date_idx:max_date_idx, ddf[min_date_idx:max_date_idx, "ssro_sum"] .* (basin_area*1000000),label="Sub-surface Runoff", transparency=true, color=:goldenrod1, linewidth = 2)
    lines!(ax, min_date_idx:max_date_idx, ddf[min_date_idx:max_date_idx, "streamflow"] .* 24*60*60, label="Streamflow", transparency=true, color=:darkseagreen3, linewidth = 2)
    ax.xticks = (min_date_idx+30:100:max_date_idx+30, string.(ddf[:, "date"])[min_date_idx+30:100:max_date_idx+30])
    ax.xticklabelrotation = π/4
    axislegend(ax)
    hidedecorations!(ax, ticklabels=false, ticks=false, label=false)
    save("article/png_files/runoff_daily.png", fig, px_per_unit=4)
end