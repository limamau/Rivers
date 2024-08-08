import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Compares NSE to Static Attributes
run_dict = { 
            # 'lstm_training':
            #     [
            #     'usa_time_split_adj_0807_170652',
            #     'usa_time_split_mse_3007_154911'
            #     ],
            'neuralhydrology':
                [
                'usa_time_split_nse_adaDT5_0508_103715'
                ]
            }

df_stat = pd.read_csv("static_attributes_usa_time_split.csv")
df_stat = df_stat.rename(columns={'Unnamed: 0': 'basin'})
for model_dir, run_dirs in run_dict.items():
    for run_dir in run_dirs:
        if model_dir == 'lstm_training':
            model = 'LSTM'
            epoch = '35'
        else:
            model = 'coRNN'
            epoch = '35'

        parts = run_dir.split('_')
        split_name = f"{parts[0].upper()} {parts[1].capitalize()} {parts[2].capitalize()}"
        exp_name = f"{model}: {parts[3]} {parts[4]} {parts[5]}"

        path_to_test_metrics = f"/groups/esm/achiang/Rivers/examples/catchment_models/{model_dir}/runs/{run_dir}/test/model_epoch0{epoch}/test_metrics.csv"
        df_test = pd.read_csv(path_to_test_metrics)

        # print(f"df_stat: {df_stat.head()}")
        # print(f"df_test: {df_test.head()}")
        df = pd.merge(df_test, df_stat, on='basin')
        
        # Create the 2D histogram plot
        nse = df['NSE']
        for attribute in df.columns:
            attr = df[attribute]

            attr_min = attr.min()
            attr_max = attr.max()

            plt.figure()
            plt.hist2d(nse, attr, bins=[40,40], range=[[-1,1],[attr_min, attr_max]], cmap='cool',cmin=1)

            cb = plt.colorbar(label='Number of basins')

            plt.xlabel('NSE')
            plt.ylabel(f'{attribute} index')

            plt.savefig(f"nse_vs_attr_plots/NSE_vs_{attribute}.png")
