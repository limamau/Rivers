using NetCDF
using Shapefile
using DataFrames
using JSON
using ProgressMeter

"""
    find_polygon(polygons, x, y)

Iterates over the `polygons` and finds the one containing the point `(x, y)`.
"""
function find_polygon(polygons::Vector{Union{Missing, Shapefile.Polygon}}, x::Real, y::Real)
    # Iterate over the polygons and find the one containing the point
    for i in eachindex(polygons)
        polygon = polygons[i]
        if in_polygon(polygon.points, x, y)
            return i
        end
    end
    return -1  # Point is not inside any polygon
end

"""
    verify_relative_hydro_area(hydro_area, grdc_area, threshold=0.2)

For basins with no upstreams, the function applies the "max" criteria. For basins with upstreams, verifies if the relative
difference between `hydro_area` and `grdc_area` is within a specific threshold based on the `hydro_area`.
"""
function verify_relative_hydro_area(hydro_area::AbstractFloat, grdc_area::AbstractFloat, threshold=0.2::AbstractFloat)
    if hydro_area > grdc_area
        return (hydro_area - grdc_area) / hydro_area <= threshold
    else
        return true
    end
end

"""
    verify_relative_max_area(hydro_area, grdc_area, threshold=0.2)

Verifies if the relative difference between `hydro_area` and `grdc_area` is within a specific threshold based on the 
maximum of the two areas.
"""
function verify_relative_max_area(hydro_area::AbstractFloat, grdc_area::AbstractFloat, threshold=0.2::AbstractFloat)
    return abs(hydro_area - grdc_area) / max(hydro_area, grdc_area) <= threshold
end

"""
    gauges_to_basins(nc_file, shape_file, output_file, select_best_gauge=false, verification_criteria="max", graph_dict_file="")

Maps gauges to basins based on their geographic coordinates and other criteria, and saves the mapping as a JSON file.

# Arguments
- `nc_file::String`: path to the GRDC netCDF file.
- `shape_file:::String`: path to the HydroSHEDS shapefile.
- `output_file::String`: name of the output dictionary as JSON file ({HYBAS_ID: [GRDC_ID, ...], ...}).
- `select_best_gauge::Bool`: (optional) if `true`, selects only the best gauge (maximum area of the set of gauges) 
for each basin (default: `true`).
- `verification_criteria::String`: (optional) the verification criteria to use for mapping (default: "max"). 
Currently supports ["max", "grdc"].
- `graph_dict_file::String`: (optional) path to the JSON file containing the graph dictionary.

# Output
- Saves a dictionary with the assigned gauges to the output file in JSON format.
- Common usage: **"path/to/gauge_to_basin_dict_lvXX.json"** where "XX" is the level in HydroSHEDS.

# Details
If `verification_criteria` is set to **"max"**, similar size (following threshold definition) gauge upstream area and HydroSHEDS 
basin area are obtained.
If it's set to **"grdc"**, a basin upstream area will be not smaller (whithin threshold margin in case it has no upstream) than 
the original basin area, but can be bigger (out of the threshold margin in case it has upstreams). This allows more matches and 
can be useful if routing water in-between basins is considered.
"""
function gauges_to_basins(nc_file::String, 
                          shape_file::String, 
                          output_file::String,
                          select_best_gauge=true::Bool,
                          verification_criteria="max"::String,
                          mapping_dict_file="")
    # Open the shapefile
    shape_df = Shapefile.Table(shape_file) |> DataFrame

    # Read the netCDF file
    dataset = NetCDF.open(nc_file)
    grdc_ids = dataset["gauge_id"][:]
    longitudes = dataset["geo_x"][:]
    latitudes = dataset["geo_y"][:]
    grdc_areas = dataset["area"]

    # Get graph dictionary if verification_criteria ==  "grdc"
    if verification_criteria == "grdc"
        if mapping_dict_file == ""
            error("A mapping dictionary file must be provided in 'grdc' option.")
        else
            graph_dict = JSON.parsefile(mapping_dict_file)
        end
    end

    # Create a dictionary to store the assigned points
    if select_best_gauge
        map_dict = Dict{Int, Tuple{String, Float64}}()  # {HYBAS_ID: (GAUGE_ID, GAUGE_AREA), ...}
    else
        map_dict = Dict{Int, Array{String}}()  # {HYBAS_ID: [GAUGE_ID, ...], ...}
    end
    
    # Iterate over the selected points
    msg = "Assigning gauges to basins..."
    @showprogress msg for i in eachindex(grdc_ids)
            x = longitudes[i]
            y = latitudes[i]

            # Find the polygon containing the point
            polygon_id = find_polygon(shape_df.geometry, x, y)

            # Add the point to the basin's vector of assigned points
            if polygon_id != -1
                # Verfy within verification criteria 
                if verification_criteria == "max"
                    verifies = verify_relative_max_area(shape_df[polygon_id, "SUB_AREA"], grdc_areas[i])
                
                elseif verification_criteria == "grdc"
                    # Verify if basin has upstreams
                    if isempty(graph_dict[string(shape_df[polygon_id, "HYBAS_ID"])])
                        verifies = verify_relative_max_area(shape_df[polygon_id, "SUB_AREA"], grdc_areas[i])
                    else
                        verifies = verify_relative_hydro_area(shape_df[polygon_id, "SUB_AREA"], grdc_areas[i])
                    end
                
                else
                    error("Verfication criteria not supported. Current supported verificaiton criteria are: 'max', 'grdc'.")
                end
                
                # Add the point if verifies criteria
                if verifies
                    if haskey(map_dict, shape_df[polygon_id, "HYBAS_ID"])
                        if select_best_gauge
                            if grdc_areas[i] > map_dict[shape_df[polygon_id, "HYBAS_ID"]][2]
                                map_dict[shape_df[polygon_id, "HYBAS_ID"]] = (grdc_ids[i], grdc_areas[i])
                            end
                        else
                            push!(map_dict[shape_df[polygon_id, "HYBAS_ID"]], grdc_ids[i])
                        end
                    else
                        if select_best_gauge
                            map_dict[shape_df[polygon_id, "HYBAS_ID"]] = (grdc_ids[i], grdc_areas[i])
                        else
                            map_dict[shape_df[polygon_id, "HYBAS_ID"]] = [grdc_ids[i]]
                        end
                    end
                end
            end
    end
    
    # Save dictionnary
    open(output_file,"w") do f
        JSON.print(f, map_dict)
    end
end