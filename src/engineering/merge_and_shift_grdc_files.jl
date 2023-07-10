using Dates
using NCDatasets
using ProgressMeter

"""
    insert_array!(insert_array, main_array, last_idx)
"""
function insert_array!(insert_array::Vector, main_array::Vector, last_idx::Int)
    main_array[last_idx+1 : last_idx+length(insert_array)] = insert_array
end

"""
    shift_grdc_to_utc(input_file, output_file)
Merge and shift GRDC netCDF files that are in local time to UTC and saves a new netCDF file. 
Some fields are not transferred.
"""
function merge_and_shift_grdc_files(input_dir::String, output_file::String, initial_year::Int, final_year::Int)
    # Get a list of all NetCDF files in the directory
    files = filter(f -> endswith(f, ".nc"), readdir(input_dir, join=true))

    # Open the first file to serve as the base for merging
    base_dataset = Dataset(files[1], "r")

    # Get initial and final date
    min_date = Date(initial_year, 1, 1)
    max_date = Date(final_year, 12, 31)
    
    # Find NetCDF corresponding index
    min_date_idx = findfirst(date -> date == min_date, base_dataset["time"][:])
    max_date_idx = findfirst(date -> date == max_date, base_dataset["time"][:])
    
    # Create dates array to serve as dimension for the new Dataset
    dates = base_dataset["time"][min_date_idx-1:max_date_idx]

    # Count the total number of gauges in the available files
    num_gauges = 0
    for file in files
        ds = Dataset(file, "r")
        num_gauges += length(ds["id"][:])
        close(ds)
    end

    # Create array to store:
    # shifted streamflow data for one given gauge
    streamflows = Matrix{Union{Missing, Float32}}(missing, num_gauges, length(dates))
    # gauge ids
    gauge_ids = Vector{Int32}(undef, num_gauges)
    # areas
    areas = Vector{Float32}(undef, num_gauges)
    # country
    countries = Vector{String}(undef, num_gauges)
    # geographical coordinates
    geo_Xs = Vector{Float32}(undef, num_gauges)
    geo_Ys = Vector{Float32}(undef, num_gauges)
    geo_Zs = Vector{Float32}(undef, num_gauges)
    # time zones
    timezones = Vector{Float32}(undef, num_gauges)


    # Iterate over all the files and over all the basins
    last_idx = 0
    prog = Progress(num_gauges)
    println("Shifting GRDC data to UTC...")
    for file in files
        # Read dataset
        ds = Dataset(file, "r")

        file_timezones = ds["timezone"][:]
        file_streamflows = ds["runoff_mean"][:,:]

        # Find NetCDF corresponding index
        min_date_idx = findfirst(date -> date == min_date, ds["time"][:])
        max_date_idx = findfirst(date -> date == max_date, ds["time"][:])
        # In case the last date of the dataset is before the max_date
        if isnothing(max_date_idx)
            # In case the last date of the dataset is before the min_date
            if ds["time"][end] < min_date
                continue
            else
                max_date_idx = length(ds["time"][:])
            end
        end

        # Shift and add streamflows
        for i in eachindex(ds["id"][:])
            streamflows[i, 1] = missing
            for t in min_date_idx:max_date_idx
                if !ismissing(file_streamflows[i,t])
                    # Shift streamflow
                    streamflows[last_idx+i, t-min_date_idx+2] = (file_streamflows[i,t-1]*file_timezones[i] + file_streamflows[i,t]*(24-file_timezones[i])) / 24
                end
            end
            next!(prog)
        end

        # Add corresponding variables
        # Add ids
        insert_array!(ds["id"][:], gauge_ids, last_idx)
        # Add areas
        insert_array!(ds["area"][:], areas, last_idx)
        # Add countries
        insert_array!(ds["country"][:], countries, last_idx)
        # Add geographical coordinates
        insert_array!(ds["geo_x"][:], geo_Xs, last_idx)
        insert_array!(ds["geo_y"][:], geo_Ys, last_idx)
        insert_array!(ds["geo_z"][:], geo_Zs, last_idx)
        # Add timezones
        insert_array!(ds["timezone"][:], timezones, last_idx)

        # Update id index
        last_idx += length(ds["id"][:])
    end

    # Create output NetCDF file
    if isfile(output_file)
        error("Output file already exists.")
    else
        output_dataset = NCDataset(output_file, "c")
    end

    # Create output variables associated with dimension
    defVar(output_dataset, "gauge_id", gauge_ids, ("gauge_id",))
    defVar(output_dataset, "date", dates, ("date",))

    # Create a streamflow variable
    defVar(output_dataset, "streamflow", streamflows, ("gauge_id", "date",), fillvalue=-999.0)


    # Add variables
    defVar(output_dataset, "area", areas, ("gauge_id",))
    # defVar(output_dataset, "country", countries, ("gauge_id",))
    defVar(output_dataset, "geo_x", geo_Xs, ("gauge_id",))
    defVar(output_dataset, "geo_y", geo_Ys, ("gauge_id",))
    defVar(output_dataset, "geo_z", geo_Zs, ("gauge_id",))
    defVar(output_dataset, "timezone", timezones, ("gauge_id",))

    # Close output dataset
    close(output_dataset)
end