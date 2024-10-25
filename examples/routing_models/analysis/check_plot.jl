using CSV
using DataFrames
using Dates
using CairoMakie

function main()
    base = "/groups/esm/achiang/Rivers/data_from_sampo"
    # 6050344660 -> source basin (ok)
    # 7050675400 -> rout_lv = 05 (?)
    # 3050639250 -> rout_lv = 05 (ok)
    basin_id = 3050639250
    
    # Read DataFrames
    obs_df = CSV.read(joinpath(base, "routing/timeseries/timeseries_lv05/basin_$basin_id.csv"), DataFrame)
    mizu_df = CSV.read(joinpath(base, "routing/simulations/simulations_lv05/simulation_gamma-IRF/basin_$basin_id.csv"), DataFrame)
    
    # Define date limits
    start_date = Date(1996, 01, 01)
    end_date = Date(1997, 12, 31)
    
    # Filter dates
    obs_df = filter(row -> start_date <= row[:date] <= end_date, obs_df)
    
    # Select date indexes
    mizu_df = filter(row -> start_date <= row[:date] <= end_date, mizu_df)
    
    fig = Figure()
    ax = Axis(
        fig[1,1], 
        xlabel="Number of days", 
        ylabel="Streamflow (m³/s)", 
        title="Descendent basin"
    )
    lines!(obs_df[:,:streamflow], label="Observed")
    lines!(mizu_df[:,:streamflow], label="LSTM-IRF")
    axislegend(ax)

    # save("../analysis/png_files/source_basin.png", fig)
    save("examples/routing_models/analysis/png_files/descendent_basin.png", fig)
end

main()