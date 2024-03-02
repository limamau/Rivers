import cdsapi

# Specify the desired parameters and settings
year_start, year_end = 1990, 1999
month_start, month_end = 1, 11
day_start, day_end = 1, 31
variables = ['surface_runoff', 'sub_surface_runoff', 'surface_net_thermal_radiation', 'surface_pressure',
             '2m_temperature', 'total_precipitation']
variables2 = ['total_evaporation']
product_type = "reanalysis"

# Initialize the CDS API client
c = cdsapi.Client()

for year in range(year_start, year_end + 1):
    for month in range(month_start, month_end + 1):
        print("Processing {}/{}...".format(month, year))
        # Request the data
        c.retrieve(
            "reanalysis-era5-land",
            {
                "product_type": product_type,
                "variable": variables,
                "year": [str(year)],
                "month": [str(month).zfill(2)],
                "day": [str(day).zfill(2) for day in range(day_start, day_end + 1)],
                "time": "00:00",
                "grid":['0.1','0.1'],
                "format": "netcdf",
            },
            "globe_year_month/era5_" + str(year) + "_" + str(month).zfill(2) + ".nc",
        )
