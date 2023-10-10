using CSV
using DataFrames
using Flux
using NCDatasets
using ProgressMeter

include("utils.jl")

function calculate_mass_aggregates(others_dir::String, evaporation_dir::String)
    # Read base first file in evaporation directory
    file = readdir(evaporation_dir)[1]
    e_ds = NCDataset(joinpath(evaporation_dir, file))

    # Get longitude and latitude data
    lon_dim = e_ds.dim["longitude"]
    lat_dim = e_ds.dim["latitude"]

    # State array to save mass differences
    mass_in = zeros(Union{Missing, Float64}, lon_dim, lat_dim)
    mass_out = zeros(Union{Missing, Float64}, lon_dim, lat_dim)

    # Iterate over all NetCDF files
    msg = "Iterating over years & months..."
    @showprogress msg for file in readdir(evaporation_dir)
        # Read variables from files
        ds = NCDataset(joinpath(others_dir, file))
        e_ds = NCDataset(joinpath(evaporation_dir, file))
        tp_sum = sum(ds["tp"][:,:,:], dims=3)
        e_sum = sum(e_ds["e"][:,:,:], dims=3)
        sro_sum = sum(ds["sro"][:,:,:], dims=3)
        ssro_sum = sum(ds["ssro"][:,:,:], dims=3)

        # Update mass sum array
        mass_in += tp_sum + e_sum # here we follow the sense convention adopted by ERA5
        mass_out += sro_sum + ssro_sum
    end

    return (mass_in)[:,:,1], (mass_out)[:,:,1]
end

function calculate_relative_difference(arr1, arr2)
    return (arr1 .- arr2) ./ arr1
end

function convolute_array(length_size, arr)
    weights = Float32.(ones(length_size, length_size, 1, 1) ./ (length_size^2))
    bias = Float32.(zeros(1))
    convolution_layer = Conv(weights, bias, identity)
    lon, lat = size(arr)
    replaced_arr = replace(arr, missing => NaN)
    reshaped_arr = reshape(replaced_arr, lon, lat, 1, 1)
    output = convolution_layer(reshaped_arr)
    return output[:,:,1,1]
end

function get_longitudes_and_latitudes(nc_file::String)
    # Read NCDataset from base file
    ds = NCDataset(nc_file)

    # Get variables from dimensions
    longitudes = ds["longitude"][:]
    standard_longitudes!(longitudes)
    latitudes = ds["latitude"][:]

    return longitudes, latitudes
end

function plot_histogram(diffs::Matrix{Union{Missing, Float64}}, threshold::Real, output_file::String)
    # Define array to store histogram values
    histogram_diffs::Vector{Float64} = Float64[]

    lon_dim, lat_dim = size(diffs)
    
    msg = "Iterating values for histogram..."
    n_outliers = 0
    @showprogress msg for i in 1:lon_dim
        for j in 1:lat_dim
            if !ismissing(diffs[i,j])
                if abs(diffs[i,j]) <= threshold
                    push!(histogram_diffs, diffs[i,j])
                else
                    n_outliers += 1
                end
            end
        end
    end

    # Define figure and axis
    fig = Figure()
    ax = Axis(fig[1,1], title="Relative (P-E) - (Rs+Rss) from grid", ylabel="N of points", xlabel="Relative difference")

    # Plot histogram
    hist!(ax, histogram_diffs, bins=100)
    text!(-threshold+0.1, 200, text="N of outliers: $n_outliers") # TODO: fix text position

    # Save figure
    save(output_file, fig)
end

function plot_map(global_shapefile::String, longitudes::Vector{Float32}, latitudes::Vector{Float32}, arr, output_file::String)
    # Define figure and axis
    fig = Figure()
    ax = Axis(fig[1, 1])
    
    # Plot HydroBASINS lv01 to be used as base map
    shp_lv01_df = Shapefile.Table(global_shapefile) |> DataFrame
    foreach(shp_lv01_df.geometry) do geo
        poly!(ax, geo, color=:grey20)
    end

    # Define color range
    color_range = (-2,2)

    # Plot heatmap
    heatmap!(longitudes, latitudes, arr, colormap=:RdBu, colorrange=color_range)
    Colorbar(fig[1,2], colormap = :RdBu, limits=color_range)

    # Define title of the plot
    ax.title = "Relative differences between P-E and Runoff in the grid"
    
    # Save
    save(output_file, fig, px_per_unit=4)
end

function read_mass_aggregates(mass_aggregate_file)
    ds = NCDataset(mass_aggregate_file)
    return ds["mass_in"][:,:], ds["mass_out"][:,:]
end

function save_mass_balance_netcdf(mass_in, mass_out, diffs, evaporation_dir, output_dir)
    mkpath(output_dir)

    # Read base first file in evaporation directory
    file = readdir(evaporation_dir)[1]
    e_ds = NCDataset(joinpath(evaporation_dir, file))

    # Get longitude and latitude arrays
    longitudes = e_ds["longitude"][:]
    standard_longitudes!(longitudes)
    latitudes = e_ds["latitude"][:]

    # Create output NetCDF file
    output_file = joinpath(output_dir, "mass_balance.nc")
    if isfile(output_file)
        rm(output_file)
    end
    mass_ds = NCDataset(output_file, "c")

    # Create output variables associated with dimension
    defVar(mass_ds, "longitude", longitudes, ("longitude",))
    defVar(mass_ds, "latitude", latitudes, ("latitude",))

    # Create mass variables
    defVar(mass_ds, "mass_in", mass_in, ("longitude", "latitude",))
    defVar(mass_ds, "mass_out", mass_out, ("longitude", "latitude",))
    defVar(mass_ds, "relative_diff", diffs, ("longitude", "latitude",))

    # Close output dataset
    close(mass_ds)
end

function standard_longitudes!(longitudes::Vector{<:Real})
    for i in 1:length(longitudes)
        if longitudes[i] > 180
            longitudes[i] -= 360
        end
    end
end

# Start run here
let
    # Directories with NetCDF files information
    others_dir = "/central/scratch/mdemoura/data/era5/globe_year_month"
    evaporation_dir = "/central/scratch/mdemoura/data/era5/evaporation_year_month"

    # Calculate mass aggregates -- run if first time (slow)
    # mass_in, mass_out = calculate_mass_aggregates(others_dir, evaporation_dir)

    # Read mass balance -- default (fast)
    mass_aggregate_file = "/central/scratch/mdemoura/data/era5/mass_balance/mass_balance.nc"
    mass_in, mass_out = read_mass_aggregates(mass_aggregate_file)

    # Get relative difference
    diffs = calculate_relative_difference(mass_in, mass_out)

    # Save mass_in and mass_out as NetCDF files -- use if first time
    # output_dir = "/central/scratch/mdemoura/data/era5/mass_balance/"
    # save_mass_balance_netcdf(mass_in, mass_out, diffs, evaporation_dir, output_dir)

    # Plot histogram
    output_file = "runoff_validation/png_files/histogram_grid.png"
    threshold = 5.0
    plot_histogram(diffs, threshold, output_file) # TODO: uncomment

    # Get latitude and longitude arrays
    global_shapefile = "/central/scratch/mdemoura/data/BasinATLAS_v10_shp/BasinATLAS_v10_lev01.shp"
    file = readdir(evaporation_dir)[1]
    nc_file = joinpath(evaporation_dir, file)
    longitudes, latitudes = get_longitudes_and_latitudes(nc_file)
    
    # Plot original map
    output_file = "runoff_validation/png_files/map_grid.png"
    plot_map(global_shapefile, longitudes, latitudes, diffs, output_file) # TODO: uncomment

    # Convolute the mass balance
    length_size = 10
    convoluted_mass_in = convolute_array(length_size, mass_in)
    convoluted_mass_out = convolute_array(length_size, mass_out)
    convoluted_diffs = calculate_relative_difference(convoluted_mass_in, convoluted_mass_out)
    output_file = "runoff_validation/png_files/map_grid_conv.png"
    plot_map(global_shapefile, 
             longitudes[Int(length_size/2):Int(end-length_size/2)], 
             latitudes[Int(length_size/2):Int(end-length_size/2)],
             convoluted_diffs, 
             output_file)
end