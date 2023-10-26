using Rivers
using CairoMakie
using DataFrames
using GeometryBasics
using JSON
using NCDatasets
using Shapefile

let
    # Select files and constants
    era5_nc_file = "/central/scratch/mdemoura/Rivers/source_data/era5/globe_year_month/era5_1990_01.nc"
    shp_file = "/central/scratch/mdemoura/Rivers/source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev07.shp"
    grid_to_basins_dir = "/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/grid_to_basins_dict_lv07"
    basin = 2070017000
    
    # Open shapefiles in DataFrame format
    basins_df = Shapefile.Table(shp_file) |> DataFrame
    
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
    shape_df = Shapefile.Table(shp_file) |> DataFrame

    # Define plot
    fig = Figure()
    ax = Axis(fig[1,1], 
              xlabel = "Longitude",
              ylabel = "Latitude",
              limits = (x_min, x_max, y_min, y_max))

    # Surroundings
    for row in eachrow(shape_df)
        if string(row.HYBAS_ID)[1:3] == string(basin)[1:3]
            polygon = row.geometry
            polygon_x = [point.x for point in polygon.points]
            polygon_y = [point.y for point in polygon.points]
            points = Point2f.(polygon_x, polygon_y)
            poly!(ax=ax, points, color=(:snow2, 1), strokewidth=2, strokecolor=:black)
        end
    end

    # Basin
    polygon =  shape_df[shape_df.HYBAS_ID .== basin, :geometry][1]
    polygon_x = [point.x for point in polygon.points]
    polygon_y = [point.y for point in polygon.points]
    points = Point2f.(polygon_x, polygon_y)
    poly!(ax=ax, points, color=(:red, 0.3), strokewidth=2, strokecolor=:black)

    # Points
    sc = scatter!(basin_longitudes, basin_latitudes, color=basin_probas,
                  ax=ax,
                  lab="ERA5 data", 
                  colormap=:blues,
                  colorrange=(0,1),
                  markersize=13)

    # Colorbar
    Colorbar(fig[1,2], sc, label="Weights")

    # Save Plot
    save("article/png_files/monte_carlo.png", fig, px_per_unit=4)
end