using Rivers

function is_box_inside_basin(longitude::Real, latitude::Real, vertices::Vector{Shapefile.Point}, box_size::Real)
    if in_polygon(vertices, longitude-box_size/2, latitude-box_size/2) &&
       in_polygon(vertices, longitude+box_size/2, latitude-box_size/2) &&
       in_polygon(vertices, longitude-box_size/2, latitude+box_size/2) &&
       in_polygon(vertices, longitude+box_size/2, latitude+box_size/2)
        return true
    else
        return false
    end 
end

function get_basin_from_gauge(target_gauge_id::Integer, dict_list::Vector{Dict{String, Any}})::Tuple{Int, String}
    for basin_gauge_dict in dict_list
        lv = first(basin_gauge_dict)[1][2:3]
        for (basin_id, gauge_id) in basin_gauge_dict
            if gauge_id[1] == target_gauge_id
                return parse(Int, basin_id), lv
            end
        end
    end

    return error("Basin not find.")
end

function isvalid(coord)
    return -180 <= coord <= 360
end

function find_closest_index(grdc_coords, coords, delta)
    # Sort GRDC coordinates saving original index
    indexed_grdc = [(element, index) for (index, element) in enumerate(grdc_coords)]
    if coords[2] > coords[1]
        sort!(indexed_grdc, by=x->x[1])
    else
        sort!(indexed_grdc, by=x->x[1], rev=true)
    end
    
    # Define closest index array
    closest_idx = Vector{Union{Missing,Int}}(missing, length(grdc_coords))

    # Iterate over map coordinates
    i = j = 1
    while j <= length(grdc_coords)
        if isvalid(indexed_grdc[j][1])
            if abs(coords[i] - indexed_grdc[j][1]) <= delta/2
                closest_idx[indexed_grdc[j][2]] = i
                j = j + 1
            else
                i = i + 1
            end
        else
            j = j + 1
        end
    end

    return closest_idx
end

function first_dates_of_months(min_date, max_date)
    current_date = min_date
    first_dates = Date[]
    
    while current_date <= max_date
        push!(first_dates, current_date)
        current_date = Dates.lastdayofmonth(current_date) + Day(1)
    end
    
    return first_dates
end

function get_year_and_month_river(nc_file::String)
    # Check if the filename has the correct format
    if occursin("river_", nc_file) && occursin(".nc", nc_file)
        # Extract year and month as strings
        parts = split(split(nc_file, "/")[end], "_")
        if length(parts) == 3
            year_str = parts[2]
            month_str = parts[3][1:2]

            # Convert the strings to integers
            year = parse(Int16, year_str)
            month = parse(Int16, month_str)
        else
            error("Invalid nc_file format.")
        end
    else
        error("Invalid nc_file format.")
    end

    return year, month
end