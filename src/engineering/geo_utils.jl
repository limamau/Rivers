using Shapefile

export in_polygon

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