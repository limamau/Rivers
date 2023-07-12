using Rivers
using CairoMakie
using DataFrames
using JSON
using NetCDF
using Random
using Shapefile 

# Set up files and variables to test
nc_file = "path/to/file.nc" 
shp_file = "/path/to/file.shp" 
basin_id_field = "HYBAS_ID"
output_dir = "/path/to/grid_to_basins_dict_lvXX/"
do_monte_carlo = true 
num_mc_exp = 100

# Compute an save JSON dictionary
grid_points_to_basins(nc_file, shp_file, basin_id_field, output_dir, do_monte_carlo, num_mc_exp)

# Read directory with dictionaries
grid_to_basins_dict_files = readdir(output_dir, join=true)

# Choose one of the files randomly
Random.seed!(42)
random_file = rand(grid_to_basins_dict_files)

# Read dictionary
map_dict = JSON.parsefile(random_file)

# Get random basin
basin_id = rand(keys(map_dict))

# Read the netCDF file
dataset = NetCDF.open(nc_file)
longitudes = (dataset["longitude"][:])
standard_longitudes!(longitudes)
latitudes = dataset["latitude"][:]

# Definition of the vectors to plot
basin_longitudes = [longitudes[map_dict[basin_id][i][1]] for i in 1:length(map_dict[basin_id])]
basin_latitudes = [latitudes[map_dict[basin_id][i][2]] for i in 1:length(map_dict[basin_id])]
probas = [map_dict[basin_id][i][3] for i in 1:length(map_dict[basin_id])]

# Define plot
fig = Figure()
ax = Axis(fig[1, 1])

# Open the shapefile in DataFrame format
shape_df = Shapefile.Table(shp_file) |> DataFrame

# Basin
for polygon in shape_df[shape_df.HYBAS_ID .==parse(Int, basin_id), :].geometry
    polygon_x = [point.x for point in polygon.points]
    polygon_y = [point.y for point in polygon.points]
    points = Point2f.(polygon_x, polygon_y)
    poly!(points, color=(:dodgerblue, 1))
end

# Points
sc = CairoMakie.scatter!(basin_longitudes, basin_latitudes, color=probas,
                    ax=ax,
                    lab="ERA5 data", 
                    colormap=:OrRd,
                    colorrange=(0,1),
                    markersize=10)

# Finals
Colorbar(fig[1,2], sc, label="Point weights")
ax.title = "Basin " * basin_id * " with Monte Carlo"

# Save Plot
save("examples/engineering/monte_carlo_basin_map.png", fig)