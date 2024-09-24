import sys
sys.path.append('plotting')
from obs_vs_sim_plots import obs_vs_sim_plot
from CDF_plots import cdf_plot
from NSE_vs_epochs import NSE_plot
from collections import defaultdict
import matplotlib.pyplot as plt
import os
import numpy as np

if __name__ == "__main__":
    run_dirs = { 
                'lstm_training':
                    [
                    'usa_time_split_nse_log_1508_140939',
                    'usa_time_split_mse_log_1508_140556'
                    ],
                'neuralhydrology':
                    [
                    'usa_time_split_nse_adaDT5_logQ3_1208_143346',
                    'usa_time_split_mse_adaDT5_logQ3_1308_113840'
                    ]
                }

    OvS = []
    CDF = []
    MED_NSE = []
    metric = 'NSE'

    for model_dir, run_dirs in run_dirs.items():
        for run_dir in run_dirs:
            if model_dir == 'lstm_training':
                model = 'LSTM'
                epoch = '35'
                if run_dir == 'usa_time_split_nse_log_1508_140939':
                    exp_name = f"LSTM: NSE"
                if run_dir == 'usa_time_split_mse_log_1508_140556':
                    exp_name = f"LSTM: MSE"
            else:
                model = 'coRNN'
                epoch = '35'
                if run_dir == 'usa_time_split_nse_adaDT5_logQ3_1208_143346':
                    exp_name = f"coRNN: NSE"
                if run_dir == 'usa_time_split_mse_adaDT5_logQ3_1308_113840':
                    exp_name = f"coRNN: MSE"

            parts = run_dir.split('_')
            split_name = f"{parts[0].upper()} {parts[1].capitalize()} {parts[2].capitalize()}"

            # exp_name = f"{model}: {parts[3]} {parts[4]} {parts[5]}"

            # Plot observed vs simulated trajectory
            qobs, qsim = obs_vs_sim_plot(model_dir, run_dir, epoch)
            OvS.append((qobs, qsim, exp_name))

            # Plot CDF of test metric (default: 'NSE') 
            nse, cdf = cdf_plot(model_dir, run_dir, epoch, metric)
            CDF.append((nse, cdf, exp_name))

            # Plot Median NSE vs Epochs
            ep, med_nse = NSE_plot(model_dir, run_dir, epoch)
            MED_NSE.append((ep, med_nse, exp_name))
    
    if True:
        plot_folder = 'final_report'
        if not os.path.exists(f'plots/{plot_folder}'):
            os.makedirs(f'plots/{plot_folder}')

        # Plot all CDFs on the same figure
        plt.figure(1)
        for (nse, cdf, exp_name) in CDF:
            plt.plot(nse, cdf, label=exp_name)
        plt.xlabel(metric)
        plt.ylabel('CDF')
        plt.title(f'{split_name}: CDF of {metric} for {epoch} epochs')
        plt.xlim(0,1)
        plt.ylim(-0.1,1.1)
        plt.grid(True)
        plt.legend()
        fig_path = f'plots/{plot_folder}/CDF_{metric}.png'
        plt.savefig(fig_path, dpi=300)
        plt.close()

        # Plot all median NSE on the same figure
        min_nse = 0
        max_nse = 0
        plt.figure(2)
        for (ep, med_nse, exp_name) in MED_NSE:
            print(exp_name)
            plt.plot(ep, med_nse, '-o', label=exp_name)
            min_nse = min(min_nse, min(med_nse))
            max_nse = max(max_nse, max(med_nse))
        plt.xlabel('Epoch')
        plt.ylabel('NSE') 
        plt.title(split_name + ': Median NSE vs Epoch')
        plt.grid(True)
        # plt.xlim(0, int(epoch) + 1)
        # plt.ylim(-1.5, 0.6)
        plt.legend()
        fig_path = f'plots/{plot_folder}/NSE_per_epoch.png'
        plt.savefig(fig_path, dpi=300)
        plt.close()


        # Plot observed vs simulated trajecory
        plt.figure(3, figsize=(16,10))
        qobs, _, _ = OvS[0]
        for (qobs, qsim, exp_name) in OvS:
            plt.plot(qsim['date'], qsim, label=f'{exp_name}')
        plt.plot(qobs['date'], qobs, label='Observed')
        plt.legend()
        plt.ylabel("Discharge (mm/d)")
        plt.title(f"Observed vs Simulated Trajectory")
        fig_path = f'plots/{plot_folder}/obs_vs_sim3.png'
        plt.savefig(fig_path, dpi=300)
        plt.close()