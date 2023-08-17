using Shapefile

export in_polygon, find_min_max_lon_lat, standard_longitudes!

"""
    in_polygon(vertices, x, y)

Checks if a point `(x, y)` is inside a polygon `(vertices)` using the ray casting algorithm.
"""
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

"""
    find_min_max_lon_lat(points, margin)

Finds the minimum and maximum longitude and latitude values from a list of `points`.
The `margin` is given to increase the range of the minimum and maximum.
"""
function find_min_max_lon_lat(points::Vector{Shapefile.Point}, margin::Real)
    polygon_longitudes = [point.x for point in points]
    polygon_latitudes = [point.y for point in points]

    return minimum(polygon_longitudes) - margin, maximum(polygon_longitudes) + margin,
           minimum(polygon_latitudes) - margin, maximum(polygon_latitudes) + margin
end

"""
    standard_longitudes!(longitudes)

Transforms an array of longitudes to the [-180,180] limit range.
"""
function standard_longitudes!(longitudes::Vector{<:Real})
    for i in 1:length(longitudes)
        if longitudes[i] > 180
          longitudes[i] -= 360
        end
      end
end