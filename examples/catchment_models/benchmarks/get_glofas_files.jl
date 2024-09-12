using CSV
using DataFrames
using Dates
using JSON
using NCDatasets
using ProgressMeter
using Shapefile

include("utils.jl")

function write_csv_files(
    grdc_idxs,
    grdc_ids,
    key_gauges,
    basin_gauge_dict_lv05,
    basin_gauge_dict_lv06,
    basin_gauge_dict_lv07,
    glofas_areas,
    grdc_areas,
    glofas_ds,
    glofas_lon_idxs,
    glofas_lat_idxs,
    glofas_min_date_idx,
    glofas_max_date_idx,
    grdc_streamflows,
    grdc_min_date_idx,
    grdc_max_date_idx,
    min_date,
    max_date,
    output_dir,
    gauge_area_dict,
    area_cutoff,
    key_gauges_cutoff
)
    for i in eachindex(grdc_idxs)
        grdc_idx = grdc_idxs[i]
        gauge_id = grdc_ids[grdc_idx]
        # Check if gauge has a corresponding basin
        if gauge_id in key_gauges
            basin_id, lv = get_basin_from_gauge(gauge_id, [basin_gauge_dict_lv05, basin_gauge_dict_lv06, basin_gauge_dict_lv07])

            if is_area_within_threshold(
                glofas_areas[i], 
                grdc_areas[grdc_idx],
            )
                glofas_arr = glofas_ds["dis24"][glofas_lon_idxs[i], glofas_lat_idxs[i], glofas_min_date_idx:glofas_max_date_idx]
                grdc_arr = grdc_streamflows[grdc_idx, grdc_min_date_idx:grdc_max_date_idx]
                shifted_dates = collect(min_date - Day(1): Day(1) : max_date - Day(1)) # same here
                
                # Write csv
                CSV.write(
                    joinpath(output_dir, "basin_$basin_id.csv"), 
                    DataFrame(date=shifted_dates, obs=grdc_arr, sim=glofas_arr),
                    append=true,
                )

                # Write area in the json
                gauge_area_dict[string(gauge_id)] = glofas_areas[i]
            else
                area_cutoff += 1
            end
        else
            key_gauges_cutoff += 1
        end
    end

    return area_cutoff, key_gauges_cutoff
end

function main()
    # Files
    base = "/users/mlima/data_for_revisions"
    glofas_dir = joinpath("/scratch/mlima/river_year_month_nc")
    grdc_file = joinpath(base, "midway_data/GRDC-Globe/grdc-merged.nc")
    gauge_dict_lv05_file = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv05_max.json")
    gauge_dict_lv06_file = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv06_max.json")
    gauge_dict_lv07_file = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv07_max.json")
    gauged_output_dir = joinpath(base, "post_data/glofas_gauged_timeseries")
    ungauged_output_dir = joinpath(base, "post_data/glofas_ungauged_timeseries")
    gauged_area_dict_file = joinpath(base, "midway_data/era5/gauged_gauge_area_dict.json")
    ungauged_area_dict_file = joinpath(base, "midway_data/era5/ungauged_gauge_area_dict.json")
    glofas_calibration_file = joinpath(base, "internal/GRDCstations_Calib_GloFASv4.csv")
    up_areas_file = joinpath(base, "internal/uparea_glofas_v4_0.nc")
    min_global_date = Date(1989, 10, 1)
    max_global_date = Date(1999, 9, 30)
    
    # Read GloFAS base dataset
    glofas_ds = NCDataset(joinpath(glofas_dir, "river_1990_01.nc"))
    glofas_lons = glofas_ds["longitude"][:]
    glofas_lats = glofas_ds["latitude"][:]
    
    # Read upstream area used by GloFAS
    up_areas_ds = NCDataset(up_areas_file)
    up_areas = up_areas_ds["uparea"][:,:]

    # Read GRDC dataset
    grdc_ds = NCDataset(grdc_file)
    grdc_lons = grdc_ds["geo_x"][:]
    grdc_lats = grdc_ds["geo_y"][:]
    grdc_ids = grdc_ds["gauge_id"][:]
    grdc_streamflows = grdc_ds["streamflow"][:,:]
    grdc_dates = grdc_ds["date"][:]
    grdc_areas = grdc_ds["area"][:]

    # Read GloFAS calibration file
    calibration_df = CSV.read(glofas_calibration_file, DataFrame)

    # Get gauges list
    basin_gauge_dict_lv05 = JSON.parsefile(gauge_dict_lv05_file)
    basin_gauge_dict_lv06 = JSON.parsefile(gauge_dict_lv06_file)
    basin_gauge_dict_lv07 = JSON.parsefile(gauge_dict_lv07_file)

    # Indexes based on their calibration file
    gauged_grdc_idxs, gauged_glofas_lat_idxs, gauged_glofas_lon_idxs, gauged_glofas_areas = get_gauged_matches(
        calibration_df, 
        grdc_lons,
        grdc_lats,
        glofas_lons,
        glofas_lats,
    )

    # Indexes based the available gauged minus the ones in their calibration file
    ungauged_grdc_idxs, ungauged_glofas_lat_idxs, ungauged_glofas_lon_idxs, ungauged_glofas_areas = get_ungauged_matches(
        grdc_lons,
        grdc_lats,
        glofas_lons,
        glofas_lats,
        gauged_grdc_idxs,
        up_areas,
    )
    
    # Get key gauges
    key_gauges = [arr[1] for arr in values(merge(basin_gauge_dict_lv05, basin_gauge_dict_lv06, basin_gauge_dict_lv07))]

    # Dictionary to save upstream area of each gauge
    gauged_gauge_area_dict = Dict()
    ungauged_gauge_area_dict = Dict()

    # Write csvs
    rm(gauged_output_dir; force=true, recursive=true)
    mkpath(gauged_output_dir)
    rm(ungauged_output_dir; force=true, recursive=true)
    mkpath(ungauged_output_dir)
    msg = "Writing GloFAS timeseries..."
    gauged_key_gauges_cutoff = 0
    gauged_area_cutoff = 0
    ungauged_key_gauges_cutoff = 0
    ungauged_area_cutoff = 0
    @showprogress msg for file in readdir(glofas_dir, join=true)
        # Get year and month
        year, month = get_year_and_month_river(file)

        # Define min and max dates
        min_date = Date(year, month, 1)
        max_date = Dates.lastdayofmonth(min_date)
        dates = collect(min_date : Day(1) : max_date)
        
        # Read key arrays from GloFAS
        glofas_ds = NCDataset(file)
        glofas_dates = glofas_ds["time"][:]

        # Find glofas dates index
        glofas_min_date_idx = findfirst(date -> date == min_date, glofas_dates)
        glofas_max_date_idx = findfirst(date -> date == max_date, glofas_dates)

        # Find GRDC dates index
        grdc_min_date_idx = findfirst(date -> date == min_date-Day(1), grdc_dates) # ERA5 defines the aggregation of a date with the next date
        grdc_max_date_idx = findfirst(date -> date == max_date-Day(1), grdc_dates) # same here

        # Write gauged csv files
        gauged_area_cutoff, gauged_key_gauges_cutoff = write_csv_files(
            gauged_grdc_idxs,
            grdc_ids,
            key_gauges,
            basin_gauge_dict_lv05,
            basin_gauge_dict_lv06,
            basin_gauge_dict_lv07,
            gauged_glofas_areas,
            grdc_areas,
            glofas_ds,
            gauged_glofas_lon_idxs,
            gauged_glofas_lat_idxs,
            glofas_min_date_idx,
            glofas_max_date_idx,
            grdc_streamflows,
            grdc_min_date_idx,
            grdc_max_date_idx,
            min_date,
            max_date,
            gauged_output_dir,
            gauged_gauge_area_dict,
            gauged_area_cutoff,
            gauged_key_gauges_cutoff,
        )

        # Write ungauged csv files
        ungauged_area_cutoff, ungauged_key_gauges_cutoff = write_csv_files(
            ungauged_grdc_idxs,
            grdc_ids,
            key_gauges,
            basin_gauge_dict_lv05,
            basin_gauge_dict_lv06,
            basin_gauge_dict_lv07,
            ungauged_glofas_areas,
            grdc_areas,
            glofas_ds,
            ungauged_glofas_lon_idxs,
            ungauged_glofas_lat_idxs,
            glofas_min_date_idx,
            glofas_max_date_idx,
            grdc_streamflows,
            grdc_min_date_idx,
            grdc_max_date_idx,
            min_date,
            max_date,
            ungauged_output_dir,
            ungauged_gauge_area_dict,
            ungauged_area_cutoff,
            ungauged_key_gauges_cutoff,
        )
    end

    # Adjust csvs
    # TODO: this could be done inside the first for loop for better performance
    # Define your specific names for columns
    column_names = ["date", "obs", "sim"]

    # Get a list of all CSV files in the directory
    gauged_csv_files = readdir(gauged_output_dir, join=true)
    ungauged_csv_files = readdir(ungauged_output_dir, join=true)
    csv_files = vcat(gauged_csv_files, ungauged_csv_files)

    # Iterate over each CSV file
    matchs = 0
    for csv_file in csv_files
        matchs += 1
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
    open(gauged_area_dict_file, "w") do f
        JSON.print(f, gauged_gauge_area_dict)
    end
    open(ungauged_area_dict_file, "w") do f
        JSON.print(f, ungauged_gauge_area_dict)
    end

    println("Matchs after filters: ", matchs)
    println("Gauged key gauges cutoff: ", gauged_key_gauges_cutoff/length(readdir(glofas_dir)))
    println("Ungauged key gauges cutoff: ", ungauged_key_gauges_cutoff/length(readdir(glofas_dir)))
    println("Gauged area cutoff: ", gauged_area_cutoff/length(readdir(glofas_dir)))
    println("Ungauged area cutoff: ", ungauged_area_cutoff/length(readdir(glofas_dir)))
end


if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
