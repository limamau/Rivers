import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Compares NSE to Static Attributes
run_dict = { 
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

df_stat = pd.read_csv("static_attributes_usa_time_split.csv")
df_stat = df_stat.rename(columns={'Unnamed: 0': 'basin'})

# Extract attributes
attributes = df_stat.columns[df_stat.columns != 'basin']  # Exclude 'basin'

for attribute in attributes:
    # Create a figure with 4 subplots (2x2 grid)
    fig, axs = plt.subplots(2, 2)
    fig.suptitle(f'USA Time Split : NSE vs {attribute}', fontsize=16)

    subplot_idx = 0

    for model_dir, run_dirs in run_dict.items():
        for run_dir in run_dirs:
            # Determine model and experiment name for current subplot
            if model_dir == 'lstm_training':
                model = 'LSTM'
                if run_dir == 'usa_time_split_nse_log_1508_140939':
                    exp_name = f"{model}: NSE"
                if run_dir == 'usa_time_split_mse_log_1508_140556':
                    exp_name = f"{model}: MSE"
            else:
                model = 'coRNN'
                if run_dir == 'usa_time_split_nse_adaDT5_logQ3_1208_143346':
                    exp_name = f'{model}: NSE'
                if run_dir == 'usa_time_split_mse_adaDT5_logQ3_1308_113840':
                    exp_name = f'{model}: MSE'

            parts = run_dir.split('_')
            split_name = f"{parts[0].upper()} {parts[1].capitalize()} {parts[2].capitalize()}"

            path_to_test_metrics = f"/groups/esm/achiang/Rivers/examples/catchment_models/{model_dir}/runs/{run_dir}/test/model_epoch035/test_metrics.csv"
            df_test = pd.read_csv(path_to_test_metrics)
            df = pd.merge(df_test, df_stat, on='basin')

            nse = df['NSE']
            attr = df[attribute]

            attr_min = attr.min()
            attr_max = attr.max()

            ax = axs[subplot_idx // 2, subplot_idx % 2]  # Select subplot location

            h = ax.hist2d(nse, attr, bins=[40, 40], range=[[-1, 1], [attr_min, attr_max]], cmap='cool', cmin=1)
            ax.set_title(exp_name)
            ax.set_xlabel('NSE')
            ax.set_ylabel(attribute)

            subplot_idx += 1

    # Adjust layout and add colorbar
    plt.tight_layout()
    fig.colorbar(h[3], ax=axs, orientation='vertical', label='Number of basins')

    # Save the figure
    plt.savefig(f"nse_vs_attr_plots/{attribute}_vs_NSE.png")

    # Close the figure to avoid memory issues
    plt.close(fig)
