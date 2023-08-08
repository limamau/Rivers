using CSV
using DataFrames
using Dates
using JSON
using NCDatasets
using Statistics
using ProgressMeter

include("utils.jl")

# Read PCR-GLOBWB2 dataset
pcr_ds = NCDataset("/central/scratch/mdemoura/data/pcr-globwb2/discharge_Global_monthly_1979-2014.nc")
pcr_lons = pcr_ds["lon"][:]
pcr_lats = pcr_ds["lat"][:]
pcr_streamflows = pcr_ds["discharge"][:,:,:]
pcr_months = pcr_ds["time"][:]
pcr_bnds = pcr_ds["time_bnds"][:,:]

# Read GRDC dataset
grdc_ds = NCDataset("/central/scratch/mdemoura/data/GRDC-Globe/grdc-merged.nc")
grdc_lons = grdc_ds["geo_x"][:]
grdc_lats = grdc_ds["geo_y"][:]
grdc_ids = grdc_ds["gauge_id"][:]
grdc_streamflows = grdc_ds["streamflow"][:,:]
grdc_dates = grdc_ds["date"][:]

# Get closests (lon and lat) index from PCR-GLOBWB2 to each GRDC gauge
closest_lons = find_closest_index(grdc_lons, pcr_lons, pcr_lons[2]-pcr_lons[1])
closest_lats = find_closest_index(grdc_lats, pcr_lats, pcr_lats[2]-pcr_lats[1])

# Define min and max dates
min_date = Date(1999, 10, 1)
max_date = Date(2009, 09, 1)
dates = first_dates_of_months(min_date, max_date)

# Find PCR dates index
pcr_min_date_idx = findfirst(date -> date == min_date, pcr_bnds[1,:])
pcr_max_date_idx = findfirst(date -> date == max_date, pcr_bnds[1,:])

# Get gauges list
basin_gauge_dict_lv05 = JSON.parsefile("/central/scratch/mdemoura/data/mapping_dicts/gauge_to_basin_dict_lv05_max.json")
basin_gauge_dict_lv06 = JSON.parsefile("/central/scratch/mdemoura/data/mapping_dicts/gauge_to_basin_dict_lv06_max.json")
basin_gauge_dict_lv07 = JSON.parsefile("/central/scratch/mdemoura/data/mapping_dicts/gauge_to_basin_dict_lv07_max.json")

# Get key gauges
key_gauges = [arr[1] for arr in values(merge(basin_gauge_dict_lv05, basin_gauge_dict_lv06, basin_gauge_dict_lv07))]

# Write csvs
grdc_arr = Vector{Union{Missing, Float32}}(missing, pcr_max_date_idx-pcr_min_date_idx+1)
output_dir = "/central/scratch/mdemoura/data/pcr-globwb2/pcr_timeseries_averaged"
mkpath(output_dir)
msg = "Writing PCR-GLOBWB2 timeseries..."
@showprogress msg for i in eachindex(grdc_ids)
    if grdc_ids[i] in key_gauges
        if !ismissing(closest_lons[i]) & !ismissing(closest_lats[i])
            pcr_arr = pcr_streamflows[closest_lons[i], closest_lats[i], pcr_min_date_idx:pcr_max_date_idx]
            for j in pcr_min_date_idx:pcr_max_date_idx
                grdc_min_date_idx = findfirst(date -> date == pcr_bnds[1,j], grdc_dates)
                grdc_max_date_idx = findfirst(date -> date == pcr_bnds[2,j], grdc_dates)
                grdc_arr[j-pcr_min_date_idx+1] = sum(grdc_streamflows[i,grdc_max_date_idx:grdc_max_date_idx])
            end
            gauge_id = grdc_ids[i]
            CSV.write(joinpath(output_dir, "gauge_$gauge_id.csv"), DataFrame(date=dates, grdc_streamflow=grdc_arr, pcr_streamflow=pcr_arr))
        end
    end
end
