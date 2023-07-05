# This script uses local files -> NEED TO CHANGE BEFORE PUSHING

using Rivers
using CairoMakie
using Dates
using NCDatasets
using Random

# Set up files to test
input_file = "path/to/GRDC/nc.file"
output_file = "path/to/GRDC/shifted/nc.file"

# Comput new shifted netCDF file
shift_grdc_to_utc(input_file, output_file)

# Read files
original_ds = NCDataset(input_file, "r")
shifted_ds = NCDataset(output_file, "r")

# Get the total number of gauges in the netCDF
n_gauges = length(original_ds["id"][:])

# Generate a random index
Random.seed!(1234)
random_index = rand(1:n_gauges)

# Select the random row to get streamflows
original_streamflow = original_ds["runoff_mean"][random_index, :]
shifted_streamflow = shifted_ds["streamflow"][random_index, :]

# Plot
fig = Figure()
ax = Axis(fig[1,1], title="Streamflow [m^3/s]")
original_num_days = length(original_ds["time"][:])
final_day = original_num_days - 365
initial_day = final_day - 20
lines!(ax, initial_day:final_day, original_streamflow[initial_day:final_day], label="Original data", transparency=true, color=:blue)
lines!(ax, initial_day:final_day, shifted_streamflow[initial_day:final_day], label="Shifted data", transparency=true, color=:red)
ax.xticks = (initial_day:5:final_day, string.(Date.(original_ds["time"][:]))[initial_day:5:final_day])
ax.xticklabelrotation = π/4
axislegend(ax)

# Save Plot
save("examples/engineering/time_shifted_grdc_streamflow.png", fig)