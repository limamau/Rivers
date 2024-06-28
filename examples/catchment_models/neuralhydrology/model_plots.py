import sys
sys.path.append('plotting')
from obs_vs_sim_plots import obs_vs_sim_plot
from CDF_plots import cdf_plot
from NSE_vs_epochs import NSE_plot


if __name__ == "__main__":
    run_dir = 'usa_time_split_2706_140255'
    epoch = '35'

    # Plot observed vs simulated trajectory
    obs_vs_sim_plot(run_dir, epoch)

    # Plot CDF of NSE
    cdf_plot(run_dir, epoch)

    # Plot Average NSE vs Epochs
    NSE_plot(run_dir, epoch)