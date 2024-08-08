import pandas as pd
import matplotlib.pyplot as plt
import os

def cdf_plot(mdoel_dir, run_dir, epoch, metric = 'NSE', plot_bool = False):
    parts = run_dir.split('_')
    split_name = f"{parts[0].upper()} {parts[1].capitalize()} {parts[2].capitalize()}"

    # Load the CSV file
    csv_path = os.path.join(f'/groups/esm/achiang/Rivers/examples/catchment_models/{mdoel_dir}/runs/{run_dir}/test/model_epoch0{epoch}/test_metrics.csv')
    df = pd.read_csv(csv_path)

    # Sort the data by NSE
    df = df.sort_values(metric)

    # Calculate the CDF values
    cdf = df[metric].rank(method='first', pct=True)

    if plot_bool:
        # Plotting the CDF
        plt.figure(figsize=(6, 6))
        plt.plot(df[metric], cdf)
        plt.xlabel(metric)
        plt.ylabel('CDF')
        plt.title(f'{split_name}: CDF of {metric} for {epoch} epochs')
        plt.xlim(0,1)
        plt.grid(True)

        if not os.path.exists(f'plots/{run_dir}'):
            os.makedirs(f'plots/{run_dir}')

        fig_path = f'plots/{run_dir}/CDF_{metric}_{epoch}.png'
        plt.savefig(fig_path, dpi=300)

        plt.close()

    return df[metric], cdf