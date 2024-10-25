using Dates
using TOML
include("../../../../src/routing/routing.jl")

function main()
    # Unpack config
    #examples/routing_models/routing/
    config = TOML.parsefile("examples/routing_models/routing/gamma-IRF/Config.toml")
    base = config["base"]["base"]
    hydro_lv = config["level"]["hydro_lv"]
    hydroatlas_shp_file = joinpath(base, config["source"]["hydroatlas_shp_file"])
    routing_levels_dir = joinpath(base, config["midway"]["routing_levels_dir"])
    basin_gauge_dict_file = joinpath(base, config["midway"]["basin_gauge_dict_file"])
    grdc_nc_file = joinpath(base, config["midway"]["grdc_nc_file"])
    routing_levels_dir = joinpath(base, config["midway"]["routing_levels_dir"])
    xd_dir = joinpath(base, config["midway"]["xd_dir"])
    attributes_dir = joinpath(base, config["simulation"]["attributes_dir"])
    graph_dict_file = joinpath(base, config["simulation"]["graph_dict_file"])
    timeseries_dir = joinpath(base, config["simulation"]["timeseries_dir"])
    simulation_dir = joinpath(base, config["simulation"]["simulation_dir"])
    start_date = Date(config["dates"]["start_date"], "yyyy-mm-dd")
    end_date = Date(config["dates"]["end_date"], "yyyy-mm-dd")
    hillslope_method = config["training"]["hillslope_method"]
    is_hillslope_training = config["training"]["is_hillslope_training"]
    river_channel_method = config["training"]["river_channel_method"]
    is_river_channel_training = config["training"]["is_river_channel_training"]

    # Route route route
    route(
        timeseries_dir,
        attributes_dir, 
        graph_dict_file, 
        routing_levels_dir,
        hillslope_method,
        is_hillslope_training,
        river_channel_method,
        is_river_channel_training,
        start_date,
        end_date,
        simulation_dir,
        1,
        1.,
        1,
        1.,
    )
end

main()