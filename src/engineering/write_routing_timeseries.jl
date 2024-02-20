using CSV
using DataFrames
using Dates
using JSON
using NCDatasets

function write_routing_timeseries(
    xd_dir::String, 
    start_date::Date, 
    end_date::Date,
    grdc_nc_file::String, 
    basin_gauge_dict_file::String,
    output_dir::String
)
    # Create directory
    mkpath(output_dir)

    # Open the NetCDF file corresponding to the gauge ID
    grdc_ds = NCDataset(grdc_nc_file)
    gauge_ids = grdc_ds["gauge_id"][:]
    dates = grdc_ds["date"][:]

    # Find NetCDF corresponding index
    start_idx = findfirst(date -> date == start_date, dates)
    end_idx = findfirst(date -> date == end_date, dates)
    
    # Read matching dictionary
    basin_gauge_dict = JSON.parsefile(basin_gauge_dict_file)

    # Allocate streamflow array
    streamflows = Vector{Float64}(undef, end_idx-start_idx+1)
    
    # Iterate over all files
    msg = "Writing new timeseries files"
    @showprogress msg for basin_file in readdir(xd_dir)
        # Read file as DataFrame
        df = CSV.read(joinpath(xd_dir, basin_file), DataFrame)
        
        # Filter the DataFrame between start_date and end_date
        df = filter(row -> start_date <= row.date <= end_date, df)

        # Read basin ID from file
        basin_id = split(basename(basin_file), "_")[end][1:end-4]

        # Check for observations
        if basin_id in keys(basin_gauge_dict)
            # Get gauge id to the corresponding basin
            gauge_id = basin_gauge_dict[basin_id][1]

            # Find its index in dataset
            gauge_idx = findfirst(id -> id == gauge_id, gauge_ids)

            # Extract the streamflow variable for the gauge id
            streamflows = grdc_ds["streamflow"][gauge_idx, start_idx:end_idx]

            # Handle missing values
            streamflows = replace(streamflows, missing => NaN)
        else
            # Write an array of NaN values
            streamflows = fill(NaN, end_idx-start_idx+1)
        end

        # Write streamflow in DataFrame
        df[!,:streamflow] = streamflows

        # Save file in new dedicated folder
        CSV.write(joinpath(output_dir, basin_file), df)
    end

    # Close the NetCDF file
    close(grdc_ds)
end