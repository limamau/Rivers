using Rivers
using CairoMakie
using DataFrames
using GeometryBasics
using JSON
using NCDatasets
using ProgressMeter
using Shapefile

# Figure height = 400 * 5
# Labels size = 17

# Note: this code still bugs sometimes... if it does, try relaunching it!

let
    # Select files and constants
    basins_shp_file = "/central/scratch/mdemoura/Rivers/source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev07.shp"
    rivers_shp_file = "/central/scratch/mdemoura/Rivers/source_data/HydroRIVERS_v10_eu_shp/HydroRIVERS_v10_eu.shp"
    grid_to_basins_dir = "/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/grid_to_basins_dict_lv07"
    basin_gauge_json_file = "/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/gauge_to_basin_dict_lv07_max_list.json"
    grdc_nc_file = "/central/scratch/mdemoura/Rivers/midway_data/GRDC-Globe/grdc-merged.nc"
    basin = 2070017000
    
    # Open shapefiles in DataFrame format
    basins_df = Shapefile.Table(basins_shp_file) |> DataFrame
    rivers_df = Shapefile.Table(rivers_shp_file) |> DataFrame # This will only work in NA
    
    # Find the basin's bounding box with a 1° margin
    basin_points =  basins_df[basins_df.HYBAS_ID .== basin, :geometry][1].points
    x_min, x_max, y_min, y_max = find_min_max_lon_lat(basin_points, 0.2)

    # Define plot
    fig = Figure(resolution=(450,400))
    ax = Axis(fig[1,1], 
              xlabel = "Latitude",
              xlabelsize = 17,
              xlabelcolor = :white,
              xticklabelcolor = :white,
              xtickcolor = :white,
              ylabel = "Longitude",
              ylabelsize = 17,
              ylabelcolor = :white,
              yticklabelcolor = :white,
              yaxisposition=:right,
              ytickcolor = :white,
              limits = (x_min, x_max, y_min, y_max))
    hidedecorations!(ax, ticks=false, ticklabels=false, label=false)

    # Surroundings
    for row in eachrow(basins_df)
        if string(row.HYBAS_ID)[1:3] == string(basin)[1:3]
            polygon = row.geometry
            polygon_x = [point.x for point in polygon.points]
            polygon_y = [point.y for point in polygon.points]
            points = Point2f.(polygon_x, polygon_y)
            poly!(ax=ax, points, color=(:seashell2, 0.7), strokewidth=2, strokecolor=:black)
        end
    end

    # Basin
    polygon =  basins_df[basins_df.HYBAS_ID .== basin, :geometry][1]
    polygon_x = [point.x for point in polygon.points]
    polygon_y = [point.y for point in polygon.points]
    points = Point2f.(polygon_x, polygon_y)
    poly!(ax=ax, points, color=(:red, 0.3), strokewidth=2, strokecolor=:black)

    # Rivers
    for order in 1:8
        println("Order: ", order)
        @showprogress for river_geometry in rivers_df[rivers_df.ORD_CLAS .== order, :geometry]
            river_x = [point.x for point in river_geometry.points]
            river_y = [point.y for point in river_geometry.points]
            points = Point2f.(river_x, river_y)
            lines!(ax=ax, points, color=(:dodgerblue, 1 - order/10))
        end
    end

    # Get gauge locations
    basin_gauge_dict = JSON.parsefile(basin_gauge_json_file)
    grdc_nc = NCDataset(grdc_nc_file)
    grdc_lons = grdc_nc["geo_x"][:]
    grdc_lats = grdc_nc["geo_y"][:]
    grdc_ids = grdc_nc["gauge_id"][:]
    grdc_areas = grdc_nc["area"][:]
    gauge_list = basin_gauge_dict[string(basin)]

    # Plot gauge locations
    gauge_ids_list = basin_gauge_dict[string(basin)]
    gauge_idxs = []
    for gauge_id in gauge_list
        push!(gauge_idxs, findfirst(id -> id == gauge_id, grdc_ids))
    end

    if length(gauge_idxs) == 2
        if grdc_areas[gauge_idxs[1]] > grdc_areas[gauge_idxs[2]]
            big_idx = gauge_idxs[1]
            small_idx = gauge_idxs[2]
        else
            small_idx = gauge_idxs[1]
            big_idx = gauge_idxs[2]
        end
    elseif length(gauge_idxs) == 1
        big_idx = gauge_idxs[1]
    else 
        error("More than 2 gauges in basin.")
    end

    scatter!([grdc_lons[big_idx]], [grdc_lats[big_idx]], strokewidth=2.5, strokecolor=:black, color=:white, markersize=15, label="Chosen gauge")
    if length(gauge_idxs) == 2
        scatter!([grdc_lons[small_idx]], [grdc_lats[small_idx]], strokewidth=1, strokecolor=:black, color=:black, label="Other gauge")
    end
    
    axislegend(ax)

    # TODO: Plot catchment areas

    # Save Plot
    save("article/png_files/gauges_and_rivers.png", fig, px_per_unit=5)
end