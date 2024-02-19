using CSV
using DataFrames
using Dates

function write_routing_timeseries(xd_dir::String, start_date::Date, end_date::Date, output_dir_dir::String)
    # Create directory
    mkpath(output_dir_dir)
    
    # Iterate over all files
    msg = "Writing new timeseries files"
    @showprogress msg for file in readdir(xd_dir)
        # Read file as DataFrame
        df = CSV.read(joinpath(xd_dir, file), DataFrame)
        
        # Filter the DataFrame between start_date and end_date
        df = filter(row -> start_date <= row.date <= end_date, df)

        # TODO: this should be only added when using the graph-LSTM scheme
        # # Add columns for 'streamflow' and 'upstream' filled with zeros
        # df[!, :streamflow] .= 0.0
        # df[!, :upstream] .= 0.0

        # Save file in new dedicated folder
        CSV.write(joinpath(output_dir_dir, file), df)
    end
end