using CSV
using DataFrames
using Dates
using JSON
using NCDatasets
using ProgressMeter

include("utils.jl")

# Read GloFAS base dataset
glofas_ds = NCDataset("/central/scratch/mdemoura/data/era5/river_year_month/river_1999_01.nc")
glofas_lons = glofas_ds["longitude"][:]
glofas_lats = glofas_ds["latitude"][:]

# Read GRDC dataset
grdc_ds = NCDataset("/central/scratch/mdemoura/data/GRDC-Globe/grdc-merged.nc")
grdc_lons = grdc_ds["geo_x"][:]
grdc_lats = grdc_ds["geo_y"][:]
grdc_ids = grdc_ds["gauge_id"][:]
grdc_streamflows = grdc_ds["streamflow"][:,:]
grdc_dates = grdc_ds["date"][:]

# Get closests (lon and lat) index from base GloFAS dataset to each GRDC gauge
closest_lons = find_closest_index(grdc_lons, glofas_lons, glofas_lons[2]-glofas_lons[1])
closest_lats = find_closest_index(grdc_lats, glofas_lats, glofas_lats[1]-glofas_lats[2])

# Get gauges list
basin_gauge_dict_lv05 = JSON.parsefile("/central/scratch/mdemoura/data/mapping_dicts/gauge_to_basin_dict_lv05_max.json")
basin_gauge_dict_lv06 = JSON.parsefile("/central/scratch/mdemoura/data/mapping_dicts/gauge_to_basin_dict_lv06_max.json")
basin_gauge_dict_lv07 = JSON.parsefile("/central/scratch/mdemoura/data/mapping_dicts/gauge_to_basin_dict_lv07_max.json")

# Get key gauges
key_gauges = [arr[1] for arr in values(merge(basin_gauge_dict_lv05, basin_gauge_dict_lv06, basin_gauge_dict_lv07))]

# Write csvs
output_dir = "/central/scratch/mdemoura/data/era5/glofas_timeseries"
mkdir(output_dir) # Make sure to have this directory uncreated as we're appending csvs
msg = "Writing GloFAS timeseries..."
@showprogress msg for file in readdir("/central/scratch/mdemoura/data/era5/river_year_month/", join=true)

    # Get year and month
    year, month = get_year_and_month_river(file)

    # Define min and max dates
    min_date = Date(year, month, 1)
    max_date = Dates.lastdayofmonth(min_date) - Day(1)
    dates = collect(min_date-Day(1) : Day(1) : max_date-Day(1)) # ERA5 defines the aggregation of a date with the next date (*)

    # Read key arrays from GloFAS
    global glofas_ds = NCDataset(file)
    glofas_streamflows = glofas_ds["dis24"][:,:,:]
    glofas_dates = glofas_ds["time"][:]

    # Find glofas dates index
    glofas_min_date_idx = findfirst(date -> date == min_date, glofas_dates)
    glofas_max_date_idx = findfirst(date -> date == max_date, glofas_dates)

    # Find GRDC dates index
    grdc_min_date_idx = findfirst(date -> date == min_date-Day(1), grdc_dates) # (*)
    grdc_max_date_idx = findfirst(date -> date == max_date-Day(1), grdc_dates) # (*)

    # Iterate over each gauge
    for i in eachindex(grdc_ids)
        # Check if gauge has a corresponding basin
        if grdc_ids[i] in key_gauges
            # Check if (lon,lat) is valid
            if !ismissing(closest_lons[i]) & !ismissing(closest_lats[i])
                glofas_arr = glofas_streamflows[closest_lons[i], closest_lats[i], glofas_min_date_idx:glofas_max_date_idx]
                grdc_arr = grdc_streamflows[i, grdc_min_date_idx:grdc_max_date_idx]
                gauge_id = grdc_ids[i]
                CSV.write(joinpath(output_dir, "gauge_$gauge_id.csv"), 
                          DataFrame(date=dates, grdc_streamflow=grdc_arr, glofas_streamflow=glofas_arr), 
                          append=true)
            end
        end
    end
end

# Adjust csvs (this could be done inside the first for loop for better performance)
# Define your specific names for columns
column_names = ["date", "grdc_streamflow", "glofas_streamflow"]

# Define the specific date range
min_global_date = Date(1999, 10, 1)
max_global_date = Date(2009, 9, 30)

# Get a list of all CSV files in the directory
csv_files = readdir(output_dir, join=true)

for csv_file in csv_files
    # Read the CSV file into a DataFrame
    df = CSV.read(csv_file, DataFrame)

    # Filter rows based on date range
    df = df[df[:,1] .>= min_global_date, :]
    df = df[df[:,1] .<= max_global_date, :]

    # Rename columns using specific names
    rename!(df, Symbol.(column_names))

    # Write the modified DataFrame back to the CSV file
    CSV.write(csv_file, df)
end