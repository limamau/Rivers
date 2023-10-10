using CairoMakie
using GeometryBasics
using Shapefile

function Makie.convert_arguments(::Type{<:Poly}, p::Shapefile.Polygon)
    # this is inefficient because it creates an array for each point
    polys = Shapefile.GeoInterface.coordinates(p)
    ps = map(polys) do pol
        Polygon(
            Point2f0.(pol[1]), # interior
            map(x -> Point2f.(x), pol[2:end]))
    end
    (ps,)
end