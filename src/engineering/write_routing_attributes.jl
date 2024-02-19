using CSV
using DataFrames
using Shapefile

function write_routing_attributes(hydroatlas_shapefile::String, output_dir::String)
    # Create directory
    mkpath(output_dir)

    # Read Hydro Atlas shapefile
    attributes_df = Shapefile.Table(hydroatlas_shapefile) |> DataFrame

    # Discard geomtry column
    select!(attributes_df, [:HYBAS_ID, :SUB_AREA, :DIST_MAIN])

    rename!(attributes_df, "SUB_AREA" => "area")

    # Write csv
    CSV.write(joinpath(output_dir, "attributes.csv"), attributes_df)
end