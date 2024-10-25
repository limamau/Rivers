using Distributed
using DataFrames, JSON, NetCDF, ProgressMeter, Shapefile

@everywhere """
    subdivide_dataframe(df, num_parts)

Subdivide a dataframe in an array of parts.
"""
function subdivide_dataframe(df::DataFrame, num_parts::Int)
    # Calculate the size of each part
    part_size, remainder = divrem(size(df, 1), num_parts)

    # Subdivide the DataFrame into equal parts
    subdivisions = []
    start_idx = 1
    for i in 1:(num_parts-1)
        end_idx = start_idx + part_size - 1 + (remainder!=0)
        push!(subdivisions, df[start_idx:end_idx, :])
        start_idx = end_idx + 1
    end
    push!(subdivisions, df[start_idx:end, :])

    return subdivisions
end

@everywhere """
    find_indices_within_range(values, min_value, max_value)

Finds the indices of values within a specified range.
"""
function find_indices_within_range(values::Vector{<:Real}, min_value::Real, max_value::Real)
    indices = findall(x -> min_value <= x <= max_value, values)
    return indices
end

@everywhere """
    grid_points_to_basins(nc_file, shp_file, basin_id_field, output_file, do_monte_carlo=true, num_mc_exp=1000)
"""
function grid_points_to_basins_in_parallel(nc_file::String, 
                                           shape_df::DataFrame,
                                           basin_id_field::String,
                                           output_file::String,
                                           do_monte_carlo=true::Bool,
                                           num_mc_exp=1000::Int)
    # Create a dictionary to store the assigned points indexes and its weights
    map_dict = Dict{Int, Vector{Tuple{Int, Int, AbstractFloat}}}()

    # Read the netCDF file
    dataset = NetCDF.open(nc_file)
    longitudes = dataset["longitude"][:]
    standard_longitudes!(longitudes)
    latitudes = dataset["latitude"][:]

    # Define constants for the Monte Carlo Experiments
    mc_proba = 1 / num_mc_exp
    std_dev = abs(longitudes[2] - longitudes[1]) / 2
    
    # Margin for the bounding box
    bb_margin = longitudes[2] - longitudes[1]

    # Iterate over the polygons
    for row in eachrow(shape_df)
        # Get the polygon's points array
        polygon_points = row.geometry.points

        # Get the minima and maxima latitude and longitude of the polygon
        min_longitude, max_longitude, min_latitude, max_latitude = find_min_max_lon_lat(polygon_points, bb_margin)
        
        # Longitude indices within the polygon's range
        longitude_indices = find_indices_within_range(longitudes, min_longitude, max_longitude)
        # Latitude indices within the polygon's range
        latitude_indices = find_indices_within_range(latitudes, min_latitude, max_latitude)
        
        # Add the polygon to the dictionary
        polygon_id = row[basin_id_field]
        push!(map_dict, polygon_id => [])

        # Iterate over the latitudes and longitudes indices within the bounding box
        # and select the indices within the polygon with its weights
        for i in longitude_indices, j in latitude_indices
            # Monte Carlo option
            if do_monte_carlo
                proba = 0
                # Perform Monte Carlo simulation
                for _ in 1:num_mc_exp
                    longitude = longitudes[i] + randn() * std_dev
                    latitude = latitudes[j] + randn() * std_dev
                    # Check if the point is inside the polygon
                    if in_polygon(polygon_points, longitude, latitude)
                        proba += mc_proba
                    end
                end
                if proba > 0
                    # Add the point to the basin's matrix of assigned points
                    push!(map_dict[polygon_id], (i, j, proba))
                end
            # No Monte Carlo option
            else
                longitude = longitudes[i]
                latitude = latitudes[j]
                if in_polygon(polygon_points, longitude, latitude)
                    # Add the point to the basin's matrix of assigned points
                    push!(map_dict[polygon_id], (i, j, 1))
                end
            end
        end
    end

    # Save dictionary
    open(output_file, "w") do f
        JSON.print(f, map_dict)
    end
end

"""
    grid_points_to_basins(nc_file, shp_file, basin_id_field, output_dir, do_monte_carlo=true, num_mc_exp=1000)

Reads a netCDF file and assigns grid points within polygons from a shapefile to basin IDs.

# Arguments
- `nc_file::String`: path to the netCDF file containing the grid information.
- `shp_file::String`: path to the shapefile containig the basins vector shapes.
- `basin_id_field::String`: name of the field in the shapefile containing the basin IDs.
- `output_dir::String`: path to the output directory to save the dictionaries (JSON files) with the assigned points.
- `do_monte_carlo::Bool`: whether to use Monte Carlo simulation for point assignment. Default is `true`.
- `num_mc_exp::Int`: number of Monte Carlo experiments to perform. Default is 1000.
- `num_parts::Int`: number of divisions on the original shapefile. Default is Sys.CPU_THREADS.

# Output
- Saves a a set of dictionaries with the assigned points to the output directory in JSON format.
- Common usage: **"path/to/grid_to_basin_dict_lvXX"** where "XX" is the level in HydroSHEDS.
"""
function grid_points_to_basins(nc_file::String, 
                               shp_file::String,
                               basin_id_field::String,
                               output_dir::String,
                               do_monte_carlo=true::Bool,
                               num_mc_exp=1000::Int,
                               num_parts=Sys.CPU_THREADS::Int)
    # Open the shapefile in DataFrame format
    shape_df = Shapefile.Table(shp_file) |> DataFrame

    # select the two used columns: geometry and basin_id_field
    select!(shape_df, [:geometry, Symbol(basin_id_field)])

    # Subdivide the DataFrame into equal parts
    subdivisions = subdivide_dataframe(shape_df, num_parts)

    # Wrapper function 
    function grid_points_to_basins_in_parallel_wrapper(i)
        output_file = joinpath(output_dir, "dict" * lpad(i,2,"0") * ".json")
        grid_points_to_basins_in_parallel(nc_file, subdivisions[i], basin_id_field, output_file, do_monte_carlo, num_mc_exp)
    end

    # Create direcoty
    mkpath(output_dir)

    # Exectute function with parallelization
    msg = "Computing points to basins..."
    @showprogress msg pmap(grid_points_to_basins_in_parallel_wrapper, 1:1:num_parts)
end