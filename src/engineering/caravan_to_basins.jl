using CSV
using DataFrames
using Shapefile
using DataFrames
using JSON
using ProgressMeter

function caravan_to_basins(attributes_dir::String, 
                          shape_file::String, 
                          output_file::String,
                          select_best_gauge=true::Bool,
                          verification_criteria="max"::String,
                          mapping_dict_file="")
    # Open the shapefile
    shape_df = Shapefile.Table(shape_file) |> DataFrame

    # Create a dictionary to store the assigned points
    if select_best_gauge
        map_dict = Dict{Int, Tuple{String, Float64}}()  # {HYBAS_ID: (GAUGE_ID, GAUGE_AREA), ...}
    else
        map_dict = Dict{Int, Array{String}}()  # {HYBAS_ID: [GAUGE_ID, ...], ...}
    end
    
    # Iterate over subdirs
    for subdir in readdir(attributes_dir)
        # Read the netCDF file
        df = CSV.read(joinpath(attributes_dir, subdir, "attributes_other_$subdir.csv"), DataFrame)
        catchment_ids = df[:, "gauge_id"]
        longitudes = df[:, "gauge_lon"]
        standard_longitudes!(longitudes)
        latitudes = df[:, "gauge_lat"]
        catchment_areas = df[:, "area"]

        # Iterate over all basins of current sub-directory
        msg = "Matching $subdir to basins..."
        @showprogress msg for i in eachindex(catchment_ids)
                x = longitudes[i]
                y = latitudes[i]

                # Find the polygon containing the point
                polygon_id = find_polygon(shape_df.geometry, x, y)

                # Add the point to the basin's vector of assigned points
                if polygon_id != -1
                    # Verfy within verification criteria 
                    if verification_criteria == "max" # Single-Basin
                        verifies = verify_relative_max_area(shape_df[polygon_id, "SUB_AREA"], catchment_areas[i])
                    
                    elseif verification_criteria == "grdc" # Graph-Routing
                        # Verify if basin has upstreams
                        if isempty(graph_dict[string(shape_df[polygon_id, "HYBAS_ID"])])
                            verifies = verify_relative_max_area(shape_df[polygon_id, "SUB_AREA"], catchment_areas[i])
                        else
                            verifies = verify_relative_hydro_area(shape_df[polygon_id, "SUB_AREA"], catchment_areas[i])
                        end
                    
                    else
                        error("Verfication criteria not supported. Current supported verificaiton criteria are: 'max', 'grdc'.")
                    end
                    
                    # Add the point if verifies criteria
                    if verifies
                        if haskey(map_dict, shape_df[polygon_id, "HYBAS_ID"])
                            if select_best_gauge
                                if catchment_areas[i] > map_dict[shape_df[polygon_id, "HYBAS_ID"]][2]
                                    map_dict[shape_df[polygon_id, "HYBAS_ID"]] = (catchment_ids[i], catchment_areas[i])
                                end
                            else
                                push!(map_dict[shape_df[polygon_id, "HYBAS_ID"]], catchment_ids[i])
                            end
                        else
                            if select_best_gauge
                                map_dict[shape_df[polygon_id, "HYBAS_ID"]] = (catchment_ids[i], catchment_areas[i])
                            else
                                map_dict[shape_df[polygon_id, "HYBAS_ID"]] = [catchment_ids[i]]
                            end
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