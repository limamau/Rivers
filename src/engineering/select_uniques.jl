using DataFrames
using Dates
using ProgressMeter

function select_uniques(input_dir::String, output_dir::String, limit_date::Union{Date, Nothing}=nothing)
    # Read csv files
    csv_files = readdir(input_dir)

    # Cretae output directory
    mkpath(output_dir)

    # Iterate over csv files
    msg = "Selecting uniques rows..."
    @showprogress msg for csv_file in csv_files
        if csv_file != "temps"
            df = CSV.read(joinpath(input_dir, csv_file), DataFrame)
            if !isnothing(limit_date)
                df = df[df.date .<= limit_date, :]
            end
            CSV.write(joinpath(output_dir, csv_file), unique(df))
        end
    end
end