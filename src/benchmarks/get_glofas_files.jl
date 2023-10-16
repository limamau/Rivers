using CSV
using DataFrames
using Dates
using JSON
using NCDatasets
using ProgressMeter
using Shapefile

include("utils.jl")

let
    # Read GloFAS base dataset
    glofas_ds = NCDataset("/central/scratch/mdemoura/Rivers/source_data/era5/river_year_month_nc/river_1999_01.nc")
    glofas_lons = glofas_ds["longitude"][:]
    glofas_lats = glofas_ds["latitude"][:]

    # Read upstream area used by GloFAS
    areas_ds = NCDataset("/central/scratch/mdemoura/Rivers/source_data/era5/uparea_glofas_v4_0.nc")
    up_areas = areas_ds["uparea"][:,:]

    # Read GRDC dataset
    grdc_ds = NCDataset("/central/scratch/mdemoura/Rivers/midway_data/GRDC-Globe/grdc-merged.nc")
    grdc_lons = grdc_ds["geo_x"][:]
    grdc_lats = grdc_ds["geo_y"][:]
    grdc_ids = grdc_ds["gauge_id"][:]
    grdc_streamflows = grdc_ds["streamflow"][:,:]
    grdc_dates = grdc_ds["date"][:]

    # Get closests (lon and lat) index from base GloFAS dataset to each GRDC gauge
    closest_lons = find_closest_index(grdc_lons, glofas_lons, glofas_lons[2]-glofas_lons[1])
    closest_lats = find_closest_index(grdc_lats, glofas_lats, glofas_lats[1]-glofas_lats[2])

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

    # Dictionary to save upstream area of each gauge
    gauge_area_dict = Dict()

    # Write csvs
    output_dir = "/central/scratch/mdemoura/Rivers/post_data/glofas_timeseries"
    mkdir(output_dir)
    msg = "Writing GloFAS timeseries..."
    @showprogress msg for file in readdir("/central/scratch/mdemoura/Rivers/source_data/era5/river_year_month_nc/", join=true)

        # Get year and month
        year, month = get_year_and_month_river(file)

        # Define min and max dates
        min_date = Date(year, month, 1)
        max_date = Dates.lastdayofmonth(min_date)
        dates = collect(min_date : Day(1) : max_date)
        # Read key arrays from GloFAS
        glofas_ds = NCDataset(file)
        glofas_streamflows = glofas_ds["dis24"][:,:,:]
        glofas_dates = glofas_ds["time"][:]

        # Find glofas dates index
        glofas_min_date_idx = findfirst(date -> date == min_date, glofas_dates)
        glofas_max_date_idx = findfirst(date -> date == max_date, glofas_dates)

        # Find GRDC dates index
        grdc_min_date_idx = findfirst(date -> date == min_date-Day(1), grdc_dates) # ERA5 defines the aggregation of a date with the next date (*)
        grdc_max_date_idx = findfirst(date -> date == max_date-Day(1), grdc_dates) # (*)

        # Iterate over each gauge
        for i in eachindex(grdc_ids)
            # Check if gauge has a corresponding basin
            if grdc_ids[i] in key_gauges
                # Check if (lon,lat) is valid
                gauge_id = grdc_ids[i]
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

                    if is_box_inside_basin(glofas_lons[closest_lons[i]], glofas_lats[closest_lats[i]], basin_vertices, glofas_lons[2]-glofas_lons[1])
                        glofas_arr = glofas_streamflows[closest_lons[i], closest_lats[i], glofas_min_date_idx:glofas_max_date_idx]
                        grdc_arr = grdc_streamflows[i, grdc_min_date_idx:grdc_max_date_idx]
                        shifted_dates = collect(min_date - Day(1): Day(1) : max_date - Day(1)) # (*)
                        
                        # Write csv
                        CSV.write(joinpath(output_dir, "gauge_$gauge_id.csv"), 
                                DataFrame(date=shifted_dates, obs=grdc_arr, sim=glofas_arr), 
                                append=true)

                        # Write area in the json
                        gauge_area_dict[string(gauge_id)] = up_areas[closest_lons[i], closest_lats[i]]
                    end
                end
            end
        end
    end

    # Adjust csvs (this could be done inside the first for loop for better performance)
    # Define your specific names for columns
    column_names = ["date", "obs", "sim"]

    # Define the specific date range
    min_global_date = Date(1990, 10, 1)
    max_global_date = Date(1999, 9, 30)

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

    # Save dictionary areas as JSON file
    json_output_file = "/central/scratch/mdemoura/Rivers/midway_data/era5/gauge_area_dict.json"
    open(json_output_file, "w") do f
        JSON.print(f, gauge_area_dict)
    end
end