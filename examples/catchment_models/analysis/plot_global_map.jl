using Rivers
using CairoMakie
using ColorSchemes
using CSV
using DataFrames
using GeometryBasics
using JSON
using NCDatasets
using Shapefile

function Makie.convert_arguments(::Type{<:Poly}, p::Shapefile.Polygon)
    # this is inefficient because it creates an array for each point
    polys = Shapefile.GeoInterface.coordinates(p)
    ps = map(polys) do pol
        Polygon(
            Point2f0.(pol[1]), # interior
            map(x -> Point2f.(x), pol[2:end]))
    end
    (ps,)
end

# Put a (*) next to the -1 border
function main()
    ## Select files and constants
    base = "/central/scratch/mdemoura/Rivers"
    shp_file = joinpath(base, "source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev01.shp")
    dict_file_lv05 = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv05_max.json")
    dict_file_lv06 = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv06_max.json")
    dict_file_lv07 = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv07_max.json")
    grdc_nc_file = joinpath(base, "midway_data/GRDC-Globe/grdc-merged.nc")
    results_file = "examples/catchment_models/analysis/csv_files/globe_all_daily.csv"
    metric = "nse"
    
    # Read shapefile as DataFrame
    shape_df = Shapefile.Table(shp_file) |> DataFrame

    # Read results of global model scores in time-split
    results_df = CSV.read(results_file, DataFrame)

    # Get gauge locations
    basin_gauge_dict = merge(JSON.parsefile(dict_file_lv05), JSON.parsefile(dict_file_lv06), JSON.parsefile(dict_file_lv07))
    grdc_nc = NCDataset(grdc_nc_file)
    grdc_lons = grdc_nc["geo_x"][:]
    grdc_lats = grdc_nc["geo_y"][:]
    grdc_ids = grdc_nc["gauge_id"][:]

    # Define vectors to plot
    number_of_scores = size(results_df)[1]
    longitudes = Vector{AbstractFloat}(undef, number_of_scores)
    latitudes = Vector{AbstractFloat}(undef, number_of_scores)
    scores = Vector{Float64}(undef, number_of_scores)

    # Iterate over basin IDs to match gauges
    for iter in 1:number_of_scores
        basin_id = results_df[iter, :basin]
        gauge_id = basin_gauge_dict[string(basin_id)][1]
        grdc_idx = findfirst(id -> id == gauge_id, grdc_ids)
        longitudes[iter] = grdc_lons[grdc_idx]
        latitudes[iter] = grdc_lats[grdc_idx]
        scores[iter] = results_df[iter, metric]
    end
    
    # Define plot
    fig = Figure(resolution=(1000,550))
    ax = Axis(fig[1,1])
    hidedecorations!(ax)
    hidespines!(ax)

    # Land mask
    foreach(shape_df.geometry) do geo
        poly!(ax, geo, color=:grey)
    end

    # Scatter plot of gauge location in the map with colors following the NSE score
    cm = :RdBu
    sc = scatter!(
        longitudes,     
        latitudes, 
        color = scores,
        colormap = cm,
        colorrange = (-1,1),
        markersize = 7,
    )

    # Colorbar
    Colorbar(
        fig[1, 2],
        colormap = cm, 
        colorrange = (-1,1), 
        label = uppercase(metric), 
        labelsize = 17,
        ticks = (-1:0.5:1, ["-1.0*", "-0.5", "0.0", "0.5", "1.0"])
    )

    # Save plot
    save("examples/catchment_models/analysis/png_files/map.png", fig, px_per_unit=4)
end

main()