# using Rivers

# TODO: put these includes in the Rivers module
include("../../../src/routing/routing.jl")

let
    # Unpack config
    config = TOML.parsefile(filename)

    base = config["base"]["base"]
    hydro_lv = config["level"]["hydro_lv"]

    hydroatlas_shp_file = config["source"]["hydroatlas_shp_file"]

    basin_gauge_dict_file = config["midway"]["basin_gauge_dict_file"]
    grdc_nc_file = config["midway"]["grdc_nc_file"]
    routing_levels_dir = config["midway"]["routing_levels_dir"]
    xd_dir = config["midway"]["xd_dir"]

    attributes_dir = config["simulation"]["attributes_dir"]
    graph_dict_file = config["simulation"]["graph_dict_file"]
    timeseries_dir = config["simulation"]["timeseries_dir"]
    simulation_dir = config["simulation"]["simulation_dir"]

    start_date = Date(config["dates"]["start_date"], "yyyy-mm-dd")
    end_date = Date(config["dates"]["end_date"], "yyyy-mm-dd")

    hillslope_method = config["training"]["hillslope_method"]
    hillslope_learning_rate = config["training"]["hillslope_learning_rate"]
    hillslope_epochs = config["training"]["hillslope_epochs"]
    river_channel_method = config["training"]["river_channel_method"]
    river_channel_learning_rate = config["training"]["river_channel_learning_rate"]
    river_channel_epochs = config["training"]["river_channel_epochs"]
    
    # Route
    route(
        timeseries_dir,
        attributes_dir, 
        graph_dict_file, 
        routing_levels_dir,
        hillslope_method,
        true,
        river_channel_method,
        false,
        start_date,
        end_date,
        simulation_dir,
        hillslope_learning_rate,
        hillslope_epochs,
        river_channel_learning_rate,
        river_channel_epochs,
    )
end