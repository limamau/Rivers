using Rivers
using CairoMakie
using ColorSchemes
using DataFrames
using GeometryBasics
using JSON
using ProgressMeter
using NCDatasets
using Shapefile

# Note: this code still bugs sometimes... if it does, try relaunching it or crtl+c to skip some river lines

let
    # Select files and constants
    era5_nc_file = "/central/scratch/mdemoura/Rivers/source_data/era5/globe_year_month/era5_1990_01.nc"
    grid_to_basins_dir = "/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/grid_to_basins_dict_lv07"
    basins_shp_file = "/central/scratch/mdemoura/Rivers/source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev07.shp"
    rivers_shp_file = "/central/scratch/mdemoura/Rivers/source_data/HydroRIVERS_v10_eu_shp/HydroRIVERS_v10_eu.shp"
    basin_gauge_json_file = "/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/gauge_to_basin_dict_lv07_max_list.json"
    grdc_nc_file = "/central/scratch/mdemoura/Rivers/midway_data/GRDC-Globe/grdc-merged.nc"
    basin = 2070017000
    
    ### Monte Carlo Plot
    print("Plotting Monte Carlo map...")
    
    # Find the basin's bounding box with a 0.2° margin
    basin_points =  basins_df[basins_df.HYBAS_ID .== basin, :geometry][1].points
    x_min, x_max, y_min, y_max = find_min_max_lon_lat(basin_points, 0.2)

    # Read directory with dictionaries
    grid_to_basins_dict_files = readdir(grid_to_basins_dir, join=true)
    
    # Find basin map array
    map_arr = []
    for file in grid_to_basins_dict_files
        map_dict = JSON.parsefile(file)
        if haskey(map_dict, string(basin))
            map_arr = map_dict[string(basin)]
            break
        end
    end

    # Read netCDF file
    dataset = NCDataset(era5_nc_file)
    longitudes = dataset["longitude"][:]
    standard_longitudes!(longitudes)
    latitudes = dataset["latitude"][:]

    # Definition of the vectors to plot
    basin_longitudes = Float64[]
    basin_latitudes = Float64[]
    basin_probas = Float64[]
    for i in eachindex(map_arr)
        push!(basin_longitudes, longitudes[map_arr[i][1]])
        push!(basin_latitudes, latitudes[map_arr[i][2]])
        push!(basin_probas, map_arr[i][3])
    end

    # Open the shapefile in DataFrame format
    shape_df = Shapefile.Table(basins_shp_file) |> DataFrame

    # Define plot
    fig = Figure(resolution=(1000,450))
    ax = Axis(fig[1,1], 
              xlabel = "Longitude",
              xlabelsize = 17,
              ylabel = "Latitude",
              ylabelsize = 17,
              limits = (x_min, x_max, y_min, y_max))
    hidedecorations!(ax, ticks=false, ticklabels=false, label=false)

    # Surroundings
    for row in eachrow(shape_df)
        polygon = row.geometry
        polygon_x = [point.x for point in polygon.points]
        polygon_y = [point.y for point in polygon.points]
        points = Point2f.(polygon_x, polygon_y)
        poly!(ax, points, color=(:seashell2, 0.7), strokewidth=2, strokecolor=:black)
    end

    # Basin
    polygon =  shape_df[shape_df.HYBAS_ID .== basin, :geometry][1]
    polygon_x = [point.x for point in polygon.points]
    polygon_y = [point.y for point in polygon.points]
    points = Point2f.(polygon_x, polygon_y)
    poly!(ax, points, color=(:red, 0.3), strokewidth=2, strokecolor=:black)

    # Points
    sc = scatter!(ax, basin_longitudes, basin_latitudes, 
                  color=basin_probas,
                  lab="ERA5 data", 
                  colormap=:Greens_6,
                  colorrange=(0,1),
                  markersize=13)

    # Colorbar
    Colorbar(fig[1,2], sc, label="Points weight", labelsize=17)
    println("Ok!")

    ### Gauges and Rivers Plot
    println("Plotting rivers and gauges...")

    # Open shapefiles in DataFrame format
    rivers_df = Shapefile.Table(rivers_shp_file) |> DataFrame

    # Define plot
    ax = Axis(fig[1,3],
              xlabel = "Longitude",
              xlabelsize = 17,
              limits = (x_min, x_max, y_min, y_max))
    hidexdecorations!(ax, ticks=false, ticklabels=false, label=false)
    hideydecorations!(ax)

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
    for order in 1:5
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
    save("examples/catchment_model/analysis/png_files/basin.png", fig, px_per_unit=4)
    println("Ok!")
end