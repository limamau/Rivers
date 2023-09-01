import CairoMakie
import CSV
import DataFrames

let
    base_dir = "/central/scratch/mdemoura/data/era5/glofas_timeseries"
    files = readdir(base_dir, join=true)
    relative_diffs = []

    for file in files
        glofas_df = CSV.read(file, DataFrame)
        # Select glofas date indexes
        glo_min_date_idx = findfirst(date -> date == Date(1993, 10, 01), glofas_df[:, "date"])
        glo_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), glofas_df[:, "date"])
        q_hat = sum(glofas_df[glo_min_date_idx:glo_max_date_idx, "glofas_streamflow"]) * 24*60*60
        q = sum(glofas_df[glo_min_date_idx:glo_max_date_idx, "grdc_streamflow"]) * 24*60*60
        relativ_diff = (q_hat - q) / q
        if !ismissing(relativ_diff)
            push!(relative_diffs, relativ_diff)
        end
    end

    fig = Figure()
    ax = Axis(fig[1,1])
    hist!(ax, relative_diffs, bins=100)
    save("article/png_files/mass_hist.png", fig)
end