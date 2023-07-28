module Rivers

export grid_points_to_basins, compute_basins_timeseries, merge_and_shift_grdc_files,
       gauges_to_basins, create_graph, merge_era5_grdc, attribute_attributes, select_uniques

export standard_longitudes! # used for plotting in the monte carlo example

include("engineering/geo_utils.jl")

include("engineering/grid_points_to_basins.jl")

include("engineering/compute_basins_timeseries.jl")

include("engineering/merge_and_shift_grdc_files.jl")

include("engineering/gauges_to_basins.jl")

include("engineering/create_graph.jl")

include("engineering/merge_era5_grdc.jl")

include("engineering/attribute_attributes.jl")

include("engineering/select_uniques.jl")

end # Rivers module