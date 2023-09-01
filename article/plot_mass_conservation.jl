using CairoMakie
using CSV
using DataFrames
using Dates
using JSON
using Statistics

# Read timeseries
basin_id = 2070510690
lv = string(basin_id)[2:3]
timeseries_df = CSV.read("/central/scratch/mdemoura/data/timeseries/timeseries_lv$lv/basin_$basin_id.csv", DataFrame)
attributes_df = CSV.read("/central/scratch/mdemoura/data/attributes/attributes_lv$lv/other_attributes.csv", DataFrame)
simulation_df = CSV.read("/central/scratch/mdemoura/data/lstm_simulations/sim_$basin_id.csv", DataFrame)

# Read basin gauge dictionary
basin_gauge_dict = JSON.parsefile("/central/scratch/mdemoura/data/mapping_dicts/gauge_to_basin_dict_lv$lv"*"_max.json")
gauge_id = basin_gauge_dict[string(basin_id)][1]
println("gauge id: ", gauge_id)
glofas_df = CSV.read("/central/scratch/mdemoura/data/era5/glofas_timeseries/gauge_$gauge_id.csv", DataFrame)

# Select timeseries date indexes
ts_min_date_idx = findfirst(date -> date == Date(1993, 01, 02), timeseries_df[:, "date"])
ts_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), timeseries_df[:, "date"])

# Select simulations date indexes
sim_min_date_idx = findfirst(date -> date == Date(1993, 01, 02), simulation_df[:, "date"])
sim_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), simulation_df[:, "date"])

# Select glofas date indexes
glo_min_date_idx = findfirst(date -> date == Date(1993, 10, 01), glofas_df[:, "date"])
glo_max_date_idx = findfirst(date -> date == Date(1999, 09, 30), glofas_df[:, "date"])

# Basin area
basin_area = attributes_df[attributes_df[:, :basin_id] .== basin_id, "area"]

# Get arrays
runoff = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "sro_sum"] .+ timeseries_df[ts_min_date_idx:ts_max_date_idx, "ssro_sum"]) * basin_area * 1000000
obs_streamflow = sum(timeseries_df[ts_min_date_idx:ts_max_date_idx, "streamflow"]) * 24*60*60
lstm_streamflow = sum(simulation_df[sim_min_date_idx:sim_max_date_idx, "sim"]) * 24*60*60
glofas_streamflow = sum(glofas_df[glo_min_date_idx:glo_max_date_idx, "glofas_streamflow"]) * 24*60*60

println("runoff: ", sum(runoff))
println("obs: ", sum(obs_streamflow))
println("lstm: ", sum(lstm_streamflow))
println("glofas: ", sum(glofas_streamflow))