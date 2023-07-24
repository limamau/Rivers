using DataFrames
using ProgressMeter

function select_uniques(input_dir::String, output_dir::String)
    # Read csv files
    csv_files = readdir(input_dir)

    # Cretae output directory
    mkdir(output_dir)

    # Iterate over csv files
    @showprogress for csv_file in csv_files
        df = CSV.read(joinpath(input_dir, csv_file), DataFrame)
        CSV.write(joinpath(output_dir, csv_file), unique(df))
    end
end