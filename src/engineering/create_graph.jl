using DataFrames
using Graphs
using JSON
using Shapefile

"""
create_graph(shape_file, output_file)

Creates a dictionnary representing the graph of basins connections in the form HYBAS -> [UP_1, ..., UP_N].

# Arguments
- `shape_file::String`: path to the shapefile containig basin informations.
- `output_dir::String`: path to the output file (JSON).
"""
function create_graph(shape_file::String, output_file::String)
    # Read shapefile as DataFrame
    df = Shapefile.Table(shape_file) |> DataFrame

    # Instantiate graph
    graph_dict = Dict{Int64, Vector{Int64}}() # HYBAS -> [UP_1, ..., UP_N] # REVIEW TYPES

    # Iterate over all basins
    for i in 1:length(df.HYBAS_ID)
        # Insert the basin in the graph with an empty list for upstreams
        graph_dict[df.HYBAS_ID[i]] = []
    end

    # Iterate over all basins
    msg = "Creating graph..."
    @showprogress msg for i in 1:length(df.HYBAS_ID)
        # Check if downstream exists in the graph
        if df.NEXT_DOWN[i] != 0
            # Add basin to the list of upstreams
            push!(graph_dict[df.NEXT_DOWN[i]], df.HYBAS_ID[i])
        end
    end

    # Create directory
    mkpath(dirname(output_file))

    # Save dictionnary
    open(output_file,"w") do f
        JSON.print(f, graph_dict)
    end
end