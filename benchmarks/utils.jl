using Shapefile

function is_area_within_threshold(area1::Real, area2::Real, threshold=0.2::Real)::Bool
    return abs(area1-area2)/max(area1, area2) <= threshold
end

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

function in_polygon(vertices::Vector{Shapefile.Point}, x::Real, y::Real)
    n = length(vertices)
    inside = false
    j = n
    for i in 1:n
        xi = vertices[i].x
        yi = vertices[i].y
        xj = vertices[j].x
        yj = vertices[j].y
        intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        if intersect
            inside = !inside
        end
        j = i
    end
    return inside
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

function mask_valid(obs::Vector{Float64}, sim::Vector{Float64})::Tuple{Vector{Float64}, Vector{Float64}}
    # mask of invalid entries. NaNs in simulations can happen during validation/testing
    idx = Vector{Bool}(undef, length(sim))
    for i in eachindex(idx)
        idx[i] = !isnan(sim[i]) & !isnan(obs[i])
    end

    obs = obs[idx]
    sim = sim[idx]

    return obs, sim
end

function get_nse(obs::Vector{Float64}, sim::Vector{Float64})::Float64
    # get time series with only valid observations
    obs, sim = mask_valid(obs, sim)

    denominator = sum((obs .- mean(obs)).^2)
    numerator = sum((sim .- obs).^2)

    value = 1.0 - numerator / denominator

    return value
end

function get_kge(obs::Vector{Float64}, sim::Vector{Float64})::Union{Missing, Float64}
    # get time series with only valid observations
    obs, sim = mask_valid(obs, sim)
    
    if isempty(obs) | isempty(sim)
        return missing
    else
        alpha = std(sim) / std(obs)
        beta = mean(sim) / mean(obs)
        r = cor(sim, obs)

        return 1 - sqrt((alpha-1)^2 + (beta-1)^2 + (r-1)^2)
    end
end