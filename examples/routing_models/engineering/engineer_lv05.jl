using Rivers
using Dates
using TOML

function main()
    # 0. Unpack configuration file
    config = TOML.parsefile("examples/routing_models/engineering/Config.toml")
    base = config["base"]["base"]
    hydro_lv = config["level"]["hydro_lv"]
    hydroatlas_shp_file = joinpath(base, config["source"]["hydroatlas_shp_file"])
    basin_gauge_dict_file = joinpath(base, config["midway"]["basin_gauge_dict_file"])
    graph_dict_file = joinpath(base, config["midway"]["graph_dict_file"])
    grdc_nc_file = joinpath(base, config["midway"]["grdc_nc_file"])
    xd_dir = joinpath(base, config["midway"]["xd_dir"])
    attributes_dir = joinpath(base, config["simulation"]["attributes_dir"])
    timeseries_dir = joinpath(base, config["simulation"]["timeseries_dir"])
    routing_levels_dir = joinpath(base, config["simulation"]["routing_levels_dir"])
    start_date = Date(config["dates"]["start_date"], "yyyy-mm-dd")
    end_date = Date(config["dates"]["end_date"], "yyyy-mm-dd")

    
    # 1. Ensure the graph is written under the simulation directory
    cp(graph_dict_file, joinpath(base, "routing/graphs/graph_lv$hydro_lv.json"), force=true)
    graph_dict_file = joinpath(base, "routing/graphs/graph_lv$hydro_lv.json")
    

    # 2. Write routing levels
    write_routing_levels(graph_dict_file, hydroatlas_shp_file, routing_levels_dir)


    # 3. Write the proper basin -> dict file
    gauges_to_basins(
        grdc_nc_file, 
        hydroatlas_shp_file, 
        basin_gauge_dict_file, 
        true,
        "grdc",
        graph_dict_file,
    )


    # 4. Write timeseries
    write_routing_timeseries(    
        xd_dir, 
        start_date, 
        end_date,
        grdc_nc_file, 
        basin_gauge_dict_file,
        timeseries_dir,
    )


    # 5. Write attributes
    write_routing_attributes(hydroatlas_shp_file, attributes_dir)
end


