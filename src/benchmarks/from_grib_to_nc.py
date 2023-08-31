import xarray as xr

year_start, year_end = 1990, 1999
month_start, month_end = 1, 12
base_dir = "/central/scratch/mdemoura/data/era5/river_year_month_grib/"
new_dir = "/central/scratch/mdemoura/data/era5/river_year_month_nc/"

for year in range(year_start, year_end + 1):
    for month in range(month_start, month_end + 1):
        file_name = "river_" + str(year) + "_" + str(month).zfill(2) + ".grib"
        ds = xr.open_dataset(base_dir + file_name)
        new_file_name = "river_" + str(year) + "_" + str(month).zfill(2) + ".nc"
        ds.to_netcdf(new_dir + new_file_name)