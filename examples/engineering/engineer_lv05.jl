# Suggestion: use one step at a time rather than runnning everything in one go.
# All the steps are currently commented, so uncomment as you go.

using Distributed

# # Launch worker processes
# num_workers = floor(Int, (parse(Int, ENV["SLURM_CPUS_PER_TASK"]) / 8))
# addprocs(num_workers, exeflags=`--project=$(Base.active_project())`)

@everywhere using Rivers, JSON

# Define your base
base = "user/path/to/Rivers"

## Define files and directories names
# ERA5
era5_nc_dir = joinpath(base, "source_data/era5/globe_year_month")
era5_nc_file = joinpath(base, era5_nc_dir, "era5_1990_01.nc")

# HydroSHEDS
hydrosheds_lv05_shp_file = joinpath(base, "source_data/BasinATLAS_v10_shp/BasinATLAS_v10_lev05.shp")

# Some midway directories
mkpath(joinpath(base, "midway_data/mapping_dicts"))
grid_to_basins_dict_lv05_dir = joinpath(base, "midway_data/mapping_dicts/grid_to_basins_dict_lv05")
variables_operations_dict = Dict("sro"=>"sum",
                                 "ssro"=>"sum",
                                 "str"=>"mean",
                                 "sp"=>"mean",
                                 "t2m"=>"mean",
                                 "tp"=>"sum")
variables_operations_dict_file = joinpath(base, "midway_data/mapping_dicts/variables_operations_dict.json")
open(variables_operations_dict_file,"w") do f
    JSON.print(f, variables_operations_dict)
end
xd_dir = joinpath("midway_data/xd_lv05")

# GRDC
original_grdc_nc_dir = joinpath(base, "source_data/GRDC-Globe")
shifted_grdc_nc_file = joinpath(base, "midway_data/GRDC-Globe/grdc-merged.nc")
basin_gauge_dict_file = joinpath(base, "midway_data/mapping_dicts/gauge_to_basin_dict_lv05_max.json")

# Single model directories
timeseries_lv05_dir = joinpath(base, "single_model_data/timeseries/timeseries_lv05")
attributes_lv05_dir = joinpath(base, "single_model_data/attributes/attributes_lv05")
timeseries_dir = joinpath(base, "single_model_data/timeseries")
attributes_dir = joinpath(base, "single_model_data/attributes")
levels = ["05"]
basin_lists_dir = joinpath(base, "single_model_data/basin_lists"


## Engineering process
# 1. Create a JSON mapping ERA5 grid points to HydroSHEDS basins with
# grid_points_to_basins(era5_nc_file, hydrosheds_lv05_shp_file, "HYBAS_ID", grid_to_basins_dict_lv05_dir, true, 500)

# 2. Compute dynamical variables for all basins with
# compute_basins_timeseries(grid_to_basins_dict_lv05_dir, era5_nc_dir, variables_operations_dict_file, xd_dir)

# 3. Ghift GRDC from local time to UTC with
# merge_and_shift_grdc_files(original_grdc_nc_dir, shifted_grdc_nc_file, 1989, 2019)

# 4. Create graph dictionary (we will skip it)
# create_graph(hydrosheds_lv05_shp_file, graph_dict_file)

# 5. Connect GRDC gauges to HydroSHEDS basins with
# gauges_to_basins(shifted_grdc_nc_file, hydrosheds_lv05_shp_file, basin_gauge_dict_file, true, "max")

# 6. Merge ERA5 timeseries for each HydroSHEDS basin with the corresponding GRDC gauge with
# merge_era5_grdc(xd_dir, shifted_grdc_nc_file, basin_gauge_dict_file, timeseries_lv05_dir)

# 7. Get the statical attributes for each basin with
# attribute_attributes(hydrosheds_lv05_shp_file, timeseries_lv05_dir, shifted_grdc_nc_file, basin_gauge_dict_file, attributes_lv05_dir)

# 8. Get the basin lists to train the models (here I'm assuming your training just one level but in general I do it with all levels instead)
# extract_basin_lists(timeseries_dir, attributes_dir, levels, basin_lists_dir) 


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
