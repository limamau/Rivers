using Rivers
using CairoMakie
using Dates
using NCDatasets
using Random

# Parameters
input_dir = "../data/GRDC-Globe"
input_file = "../data/GRDC-Globe/GRDC-Daily-39118.nc"
output_file = "../data/GRDC-Globe/grdc-merged.nc"
initial_date = Date(2009, 07, 01)
final_date = Date(2009, 07, 16)

# Merge and shift
merge_and_shift_grdc_files(input_dir, output_file, 1990, 2019)

# Read files
original_ds = NCDataset(input_file, "r")
shifted_ds = NCDataset(output_file, "r")

# Get the total number of gauges in the netCDF
n_gauges = length(original_ds["id"][:])

# Generate a random index
Random.seed!(1234)
original_random_index = rand(1:n_gauges)
shifted_random_index = findfirst(gauge_id -> gauge_id == original_ds["id"][original_random_index], shifted_ds["gauge_id"][:])

# Select the random row to get streamflows
original_streamflow = original_ds["runoff_mean"][original_random_index, :]
shifted_streamflow = shifted_ds["streamflow"][shifted_random_index, :]

# Select date indexes
original_min_date_idx = findfirst(date -> date == initial_date, original_ds["time"][:])
original_max_date_idx = findfirst(date -> date == final_date, original_ds["time"][:])
shifted_min_date_idx = findfirst(date -> date == initial_date, shifted_ds["date"][:])
shifted_max_date_idx = findfirst(date -> date == final_date, shifted_ds["date"][:])

# Plot
fig = Figure()
ax = Axis(fig[1,1], title="Streamflow [m^3/s]")
original_num_days = length(original_ds["time"][:])
lines!(ax, original_min_date_idx:original_max_date_idx, original_streamflow[original_min_date_idx:original_max_date_idx], label="Original data", transparency=true, color=:blue)
lines!(ax, original_min_date_idx:original_max_date_idx, shifted_streamflow[shifted_min_date_idx:shifted_max_date_idx], label="Shifted data", transparency=true, color=:red)
ax.xticks = (original_min_date_idx:5:original_max_date_idx, string.(Date.(original_ds["time"][:]))[original_min_date_idx:5:original_max_date_idx])
ax.xticklabelrotation = π/4
axislegend(ax)

# Save Plot
save("examples/engineering/time_shifted_grdc_streamflow.png", fig)