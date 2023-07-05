using Rivers
using CairoMakie
using DataFrames
using JSON
using NetCDF
using Random
using Shapefile 

## Set up files and variables to test
nc_file = "path/to/nc.file" 
shp_file = "path/to/shp.file" 
basin_id_field = "HYBAS_ID"
output_file = "path/to/json.file"
do_monte_carlo = true 
num_mc_exp = 100

## Compute an save JSON dictionary
grid_points_to_basins(nc_file, shp_file, basin_id_field, output_file, do_monte_carlo, num_mc_exp)

## Plot random basin
# Open the shapefile in DataFrame format
shape_df = Shapefile.Table(shp_file) |> DataFrame

# Create a dictionary to store the assigned points indexes and its weights
map_dict = JSON.parsefile(output_file)

# Read the netCDF file
dataset = NetCDF.open(nc_file)
longitudes = dataset["longitude"][:]
latitudes = dataset["latitude"][:]

# Get the total number of rows in the DataFrame
n_rows = size(shape_df, 1)

# Generate a random index
Random.seed!(42)
random_index = rand(1:n_rows)

# Select the random row
basin_id = string(shape_df[random_index, basin_id_field])

# Definition of the vectors to plot
basin_longitudes = [longitudes[map_dict[basin_id][i][1]] for i in 1:length(map_dict[basin_id])]
basin_latitudes = [latitudes[map_dict[basin_id][i][2]] for i in 1:length(map_dict[basin_id])]
probas = [map_dict[basin_id][i][3] for i in 1:length(map_dict[basin_id])]

# Define plot
fig = Figure()
ax = Axis(fig[1, 1])

# Basin
for polygon in shape_df[shape_df[:, basin_id_field] .== parse(Int, basin_id), :].geometry
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
save("monte_carlo_basin_map.png", fig)