module Rivers

export grid_points_to_basins, compute_basins_timeseries, merge_and_shift_grdc_files,
       gauges_to_basins, caravan_to_basins, create_graph, merge_era5_grdc, attribute_attributes, 
       select_uniques, extract_basin_lists, write_routing_levels, write_routing_timeseries,
       write_routing_attributes

export standard_longitudes! # used for plotting in the monte carlo example


# engineering
include("engineering/geo_utils.jl")

include("engineering/grid_points_to_basins.jl")

include("engineering/compute_basins_timeseries.jl")

include("engineering/merge_and_shift_grdc_files.jl")

include("engineering/gauges_to_basins.jl")

include("engineering/caravan_to_basins.jl")

include("engineering/create_graph.jl")

include("engineering/merge_era5_grdc_single.jl")

include("engineering/merge_era5_grdc_graph.jl")

include("engineering/attribute_attributes_single.jl")

include("engineering/attribute_attributes_graph.jl")

include("engineering/select_uniques.jl")

include("engineering/extract_basins.jl")

include("engineering/write_routing_levels.jl")

include("engineering/write_routing_timeseries.jl")

include("engineering/write_routing_attributes.jl")

end # Rivers module