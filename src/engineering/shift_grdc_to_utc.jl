using NCDatasets
using ProgressMeter

"""
    shift_grdc_to_utc(input_file, output_file)
Shift GRDC netCDF file that is in local time to UTC and saves a ned netCDF file with just the shifted streamflow.
All other information (such as geolocalization of gauges and theur upstream area) stay in the original netCDF file.
"""
function shift_grdc_to_utc(input_file::String, output_file::String)
    # Open the NetCDF file
    input_dataset = NCDataset(input_file, "r")

    # Read gauge id, time and streamflow variables
    gauge_ids = input_dataset["id"][:]
    dates = input_dataset["time"][:]
    timezones = input_dataset["timezone"][:]
    streamflows = input_dataset["runoff_mean"][:,:]

    # Close input dataset
    close(input_dataset)

    # Create array to store the shifted streamflow data for one given gauge
    shifted_streamflows = Matrix{Union{Missing, Float32}}(missing, length(gauge_ids), length(dates))

    # Iterate over dates shifting streamflow data
    println("Shifting values...")
    @showprogress for i in eachindex(gauge_ids)
        streamflows[i,1] = missing
        for t in 2:length(dates)
            if !ismissing(streamflows[i,t])
                # Shift streamflow
                shifted_streamflows[i, t] = (streamflows[i,t-1]*timezones[i] + streamflows[i,t]*(24-timezones[i])) / 24
            end
        end
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
    defVar(output_dataset, 
           "streamflow", 
           shifted_streamflows, 
           ("gauge_id", "date",), 
           fillvalue=-999.0)

    # Close output dataset
    close(output_dataset)
end