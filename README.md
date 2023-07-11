# Rivers
River model for CliMA.

## Engineering (Julia)
1. Create a set of JSON mapping ERA5 grid points to HydroSHEDS basins with `grid_points_to_basins()`.
2. Compute dynamical variables for all basins with `compute_basins_timeseries()`. Currently using netCDF files from ERA5 Land divided by year and month.
3. Merge and shift GRDC files from local time to UTC with `merge_and_shift_grdc_files()`.
4. Connect GRDC gauges to HydroSHEDS basins with `gauges_to_basins()`.
5. Merge ERA5 timeseries for each HydroSHEDS basin with the corresponding GRDC gauge with `merge_era5_grdc()`.
6. Get the statical attributes for each basin with `attribute_attributes()`.

At the end of the process you should get a "timeseries" and a "attributes" folder ready to be used by the model.

The complete engineering approach is shown in `examples/engineer.jl`.

## Neuralhydrology (Python)
Here we use a forked repository from NeuralHydrology (original: https://github.com/neuralhydrology/neuralhydrology) with an additional class to the created data set: Era5GrdcSheds. 

To use this part of the repository, make sure to:
```
cd neuralhydrology
pip install -e .
```
as shown in the documentation of the package.

A typical `config.yml` of the model in shown in `examples/neuralhydrology/NA_lv06`.

It can be run with `nh-run train --config-file config.yml`.

## Analysis (Julia)
In development.