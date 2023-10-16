using CSV
using DataFrames
using Dates
using JSON
using NCDatasets
using Shapefile
using Statistics
using ProgressMeter

include("utils.jl")

# Read PCR-GLOBWB2 dataset
pcr_ds = NCDataset("/central/scratch/mdemoura/Rivers/source_data/PCR-GLOBWB2/discharge_Global_monthly_1979-2014.nc")
pcr_lons = pcr_ds["lon"][:]
pcr_lats = pcr_ds["lat"][:]
pcr_streamflows = pcr_ds["discharge"][:,:,:]
pcr_months = pcr_ds["time"][:]
pcr_bnds = pcr_ds["time_bnds"][:,:]

# Read GRDC dataset
grdc_ds = NCDataset("/central/scratch/mdemoura/Rivers/midway_data/GRDC-Globe/grdc-merged.nc")
grdc_lons = grdc_ds["geo_x"][:]
grdc_lats = grdc_ds["geo_y"][:]
grdc_ids = grdc_ds["gauge_id"][:]
grdc_streamflows = grdc_ds["streamflow"][:,:]
grdc_dates = grdc_ds["date"][:]

# Get closests (lon and lat) index from PCR-GLOBWB2 to each GRDC gauge
closest_lons = find_closest_index(grdc_lons, pcr_lons, pcr_lons[2]-pcr_lons[1])
closest_lats = find_closest_index(grdc_lats, pcr_lats, pcr_lats[2]-pcr_lats[1])

# Define min and max dates
min_date = Date(1990, 10, 1)
max_date = Date(1999, 9, 30)
dates = first_dates_of_months(min_date, max_date)

# Find PCR dates index
pcr_min_date_idx = findfirst(date -> date == min_date, pcr_bnds[1,:])
pcr_max_date_idx = findfirst(date -> date == max_date, pcr_bnds[2,:])

# Get gauges list
basin_gauge_dict_lv05 = JSON.parsefile("/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/gauge_to_basin_dict_lv05_max.json")
basin_gauge_dict_lv06 = JSON.parsefile("/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/gauge_to_basin_dict_lv06_max.json")
basin_gauge_dict_lv07 = JSON.parsefile("/central/scratch/mdemoura/Rivers/midway_data/mapping_dicts/gauge_to_basin_dict_lv07_max.json")

# Get basins shapefiles DataFrame
hydrosheds_lv05_shp_file = "/central/scratch/mdemoura/Rivers/source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev05.shp"
hydroatlas_lv05 = Shapefile.Table(hydrosheds_lv05_shp_file) |> DataFrame
hydrosheds_lv06_shp_file = "/central/scratch/mdemoura/Rivers/source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev06.shp"
hydroatlas_lv06 = Shapefile.Table(hydrosheds_lv06_shp_file) |> DataFrame
hydrosheds_lv07_shp_file = "/central/scratch/mdemoura/Rivers/source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev07.shp"
hydroatlas_lv07 = Shapefile.Table(hydrosheds_lv07_shp_file) |> DataFrame

# Get key gauges
key_gauges = [arr[1] for arr in values(merge(basin_gauge_dict_lv05, basin_gauge_dict_lv06, basin_gauge_dict_lv07))]

# Write csvs
grdc_arr = Vector{Union{Missing, Float32}}(missing, pcr_max_date_idx-pcr_min_date_idx+1)
output_dir = "/central/scratch/mdemoura/Rivers/post_data/pcr_timeseries"
mkdir(output_dir)
msg = "Writing PCR-GLOBWB2 timeseries..."
# Iterate over each gauge
@showprogress msg for i in eachindex(grdc_ids)
    # Check if gauge has a corresponding basin
    if grdc_ids[i] in key_gauges
        gauge_id = grdc_ids[i]

        # Check if (lon,lat) is valid
        if !ismissing(closest_lons[i]) & !ismissing(closest_lats[i])
            basin_id, lv = get_basin_from_gauge(gauge_id, [basin_gauge_dict_lv05, basin_gauge_dict_lv06, basin_gauge_dict_lv07])

            # Get the right Data Frame for the basin
            if lv == "05"
                basin_vertices = hydroatlas_lv05[hydroatlas_lv05.HYBAS_ID .== basin_id, :geometry][1].points
            elseif lv == "06"
                basin_vertices = hydroatlas_lv06[hydroatlas_lv06.HYBAS_ID .== basin_id, :geometry][1].points
            elseif lv == "07"
                basin_vertices = hydroatlas_lv07[hydroatlas_lv07.HYBAS_ID .== basin_id, :geometry][1].points
            else
                error("Level $lv is not known.")
            end

            if is_box_inside_basin(pcr_lons[closest_lons[i]], pcr_lats[closest_lats[i]], basin_vertices, pcr_lons[2]-pcr_lons[1])
                # Get PCR-GLOBWB2 array
                pcr_arr = pcr_streamflows[closest_lons[i], closest_lats[i], pcr_min_date_idx:pcr_max_date_idx]
                # Get the sum of grdc streamflow over each moth and save it in the corresponding array
                for j in pcr_min_date_idx:pcr_max_date_idx
                    grdc_min_date_idx = findfirst(date -> date == pcr_bnds[1,j], grdc_dates)
                    grdc_max_date_idx = findfirst(date -> date == pcr_bnds[2,j], grdc_dates)
                    grdc_arr[j-pcr_min_date_idx+1] = sum(grdc_streamflows[i, grdc_max_date_idx:grdc_max_date_idx])
                end
                gauge_id = grdc_ids[i]
            
                # Save csv
                CSV.write(joinpath(output_dir, "gauge_$gauge_id.csv"), DataFrame(date=dates, obs=grdc_arr, sim=pcr_arr))
            end
        end
    end
end
