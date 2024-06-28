import sys
sys.path.append('plotting')
from obs_vs_sim_plots import obs_vs_sim_plot
from CDF_plots import cdf_plot
from NSE_vs_epochs import NSE_plot
from collections import defaultdict


if __name__ == "__main__":
    run_dirs = ['usa_time_split_2706_161344']
    epoch = '35'

    CDF = []
    MED_NSE = []
    for run_dir in run_dirs:
        parts = run_dir.split('_')
        split_name = f"{parts[0].upper()} {parts[1].capitalize()} {parts[2].capitalize()}"
        exp_name = f"{parts[3].capitalize()} {parts[4].lower()}" # ex: Low dt

        # Plot observed vs simulated trajectory
        obs_vs_sim_plot(run_dir, epoch)
        
        # Plot CDF of NSE
        nse, cdf = cdf_plot(run_dir, epoch)
        CDF.append((nse, cdf, exp_name))

        # Plot Median NSE vs Epochs
        ep, med_nse = NSE_plot(run_dir, epoch)
        MED_NSE.append((ep, med_nse, exp_name))
    
    if True
        # Plot all CDFs on the same figure
        plt.figure(1)
        for (nse, cdf, exp_name) in CDF:
            plt.plot(nse, cdf, label=exp_name)
        plt.xlabel('NSE')
        plt.ylabel('CDF')
        plt.title(f'{split_name}: CDF of NSE for {epoch} epochs')
        plt.xlim(0,1)
        plt.grid(True)
        plt.legend()

        # Plot all median NSE on the same figure
        plt.figure(2)
        for (ep, med_nse, exp_name) in MED_NSE:
            plt.plot(ep, med_nse, '-o', label=exp_name)
        plt.xlabel('Epoch')
        plt.ylabel('NSE') 
        plt.title(split_name + ': Median NSE vs Epoch')
        plt.grid(True)
        plt.xlim(0, int(epoch) + 1)
        plt.ylim(0, 1)
        plt.legend()