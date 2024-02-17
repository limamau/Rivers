using Distributed

# Launch worker processes
num_workers = # choose workers knowing that small amount of CPU/worker can crach the code in compute_basins_timeseries().
addprocs(num_workers, exeflags=`--project=$(Base.active_project())`)

@everywhere using Rivers, JSON

## Define files and directories names
era5_nc_dir = # this can be downloaded following https://www.ecmwf.int/en/era5-land
era5_nc_file = joinpath(era5_nc_dir, "era5_YYYY_MM.nc")
hydrosheds_lvXX_shp_file = # this can be downloaded in https://www.hydrosheds.org
mkpath("path/to/mapping_dicts")
grid_to_basins_dict_lvXX_dir = "path/to/mapping_dicts/grid_to_basins_dict_lvXX"
# Create a variable operation dict and save it as JSON to use in the example
variables_operations_dict = Dict("sro"=>"sum",
                                 "ssro"=>"sum", 
                                 "str"=>"mean", 
                                 "sp"=>"mean", 
                                 "t2m"=>"mean", 
                                 "tp"=>"sum")
variables_operations_dict_file = "path/to/mapping_dicts/variables_operations_dict.json"
open(variables_operations_dict_file,"w") do f
    JSON.print(f, variables_operations_dict)
end
xd_dir = "path/to/xd_lvXX"
original_grdc_nc_file = # this can be downloaded in https://portal.grdc.bafg.de
shifted_grdc_nc_file = "path/to/GRDC-Daily-Shifted.nc"
basin_gauge_dict_file = "path/to/mapping_dicts/gauge_to_basin_dict_lvXX.json"
timeseries_lvXX_dir = "path/to/timeseries/timeseries_lvXX"
hydroatlas_lvXX_shp_file = # this can be downloaded in https://www.hydrosheds.org
attributes_lvXX_dir = "path/to/attributes/attributes_lvXX"
timeseries_dir = "path/to/timeseries"
attributes_dir = "path/to/attributes"
levels = ["XX"]
basin_lists_dir = "path/to/basin_lists"

## Engineering process
# 1. Create a JSON mapping ERA5 grid points to HydroSHEDS basins with
grid_points_to_basins(era5_nc_file, hydrosheds_lvXX_shp_file, "HYBAS_ID", grid_to_basins_dict_lvXX_dir)
# 2. Compute dynamical variables for all basins with
compute_basins_timeseries(grid_to_basins_dict_lvXX_dir, era5_nc_dir, variables_operations_dict_file, xd_dir)
# 3. Ghift GRDC from local time to UTC with
merge_and_shift_grdc_files(original_grdc_dir, shifted_grdc_nc_file, 1990, 2019) # commonly used initial and final years
# 4. Connect GRDC gauges to HydroSHEDS basins with
gauges_to_basins(original_grdc_nc_file, hydrosheds_lvXX_shp_file, basin_gauge_dict_file)
# 5. Merge ERA5 timeseries for each HydroSHEDS basin with the corresponding GRDC gauge with
merge_era5_grdc(xd_dir, shifted_grdc_nc_file, basin_gauge_dict_file, timeseries_lvXX_dir)
# 6. Get the statical attributes for each basin with
attribute_attributes(hydroatlas_lvXX_shp_file, timeseries_lvXX_dir, original_grdc_nc_file, basin_gauge_dict_file, attributes_lvXX_dir)
# 7. Get the basin lists to train the models (here I'm assuming your training just one level)
extract_basin_lists(timeseries_dir, attributes_dir, levels, basin_lists_dir)


# ## You can choose to delete the intermediate files after the process is done:
# # Remove the dynamical inputs from era5 without streamflow timeseries if everything looks good
# # In general this is kept after 5. to be sure everything is working properly.
# rm(xd_dir, recursive=true)

# # Remove shifted GRDC netCDF
# # In general this is kept after 5. to be sure everything is working properly.
# rm(shifted_grdc_nc_file, recursive=true)

# # Remove dictionaries
# # This take some time to compute, so think about it before deleting these cuties.
# rm("mapping_dicts", recursive=true)