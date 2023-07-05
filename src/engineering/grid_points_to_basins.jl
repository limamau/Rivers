using DataFrames
using JSON
using NetCDF
using ProgressMeter
using Shapefile

"""
    find_min_max_lon_lat(points, margin)

Finds the minimum and maximum longitude and latitude values from a list of `points`.
The `margin` is given to increase the range of the minimum and maximum.
"""
function find_min_max_lon_lat(points::Vector{Shapefile.Point}, margin::AbstractFloat)
    polygon_longitudes = [point.x for point in points]
    polygon_latitudes = [point.y for point in points]

    return minimum(polygon_longitudes) - margin, maximum(polygon_longitudes) + margin,
           minimum(polygon_latitudes) - margin, maximum(polygon_latitudes) + margin
end

"""
    find_indices_within_range(values, min_value, max_value)

Finds the indices of values within a specified range.
"""
function find_indices_within_range(values::Vector{<:Real}, min_value::Real, max_value::Real)
    indices = findall(x -> min_value <= x <= max_value, values)
    return indices
end

"""
    grid_points_to_basins(nc_file, shp_file, basin_id_field, output_file, do_monte_carlo=true, num_mc_exp=1000)

Reads a netCDF file and assigns grid points within polygons from a shapefile to basin IDs.

# Arguments
- `nc_file::String`: path to the netCDF file containing the grid information.
- `shp_file::String`: path to the shapefile containig the basins vector shapes.
- `basin_id_field::String`: name of the field in the shapefile containing the basin IDs.
- `output_file::String`: path to the output file to save the assigned points.
- `do_monte_carlo::Bool`: whether to use Monte Carlo simulation for point assignment. Default is `true`.
- `num_mc_exp::Int`: number of Monte Carlo experiments to perform. Default is 1000.

# Output
- Saves a dictionary with the assigned points to the output file in JSON format.
- Common usage: **"path/to/grid_to_basin_dict_lvXX.json"** where "XX" is the level in HydroSHEDS.
"""
function grid_points_to_basins(nc_file::String, 
                               shp_file::String,
                               basin_id_field::String,
                               output_file::String, 
                               do_monte_carlo=true::Bool, 
                               num_mc_exp=1000::Int)
    # Open the shapefile in DataFrame format
    shape_df = Shapefile.Table(shp_file) |> DataFrame

    # Create a dictionary to store the assigned points indexes and its weights
    map_dict = Dict{Int, Vector{Tuple{Int, Int, AbstractFloat}}}()

    # Read the netCDF file
    dataset = NetCDF.open(nc_file)
    longitudes = dataset["longitude"][:]
    latitudes = dataset["latitude"][:]

    # Define constants for the Monte Carlo Experiments
    mc_proba = 1 / num_mc_exp
    std_dev = abs(longitudes[2] - longitudes[1]) / 2
    
    # Margin for the bounding box
    bb_margin = longitudes[2] - longitudes[1]

    println("Computing points to basins...")
    # Iterate over the polygons
    @showprogress for row in eachrow(shape_df)
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