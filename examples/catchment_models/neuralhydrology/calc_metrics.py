import os
import pandas as pd
from math import sqrt
import numpy as np

def calc_metrics(model_dir, run_dir, epoch):
    path_to_csv = f'/groups/esm/achiang/Rivers/examples/catchment_models/{model_dir}/runs/{run_dir}/test/model_epoch0{epoch}/test_metrics.csv'

    df = pd.read_csv(path_to_csv)
    df = df.dropna()

    nse = df['NSE']
    nse_lt0 = nse[nse < 0]
    print(len(nse_lt0))
    nse_gt0 = nse[nse > 0]
    nse_gt0_ci = 1.96 * (nse_gt0.std()/sqrt(len(nse_gt0)))

    pct_nse_lt0 = round(100 * len(nse_lt0)/len(nse), 2)
    mean_nse_gt0 = round(nse_gt0.mean(), 2)
    median_nse = round(nse.median(), 2)

    Q1 = round(np.quantile(nse, 0.25),2)
    Q3 = round(np.quantile(nse, 0.75),2)

    return pct_nse_lt0, mean_nse_gt0, median_nse, nse_gt0_ci, Q1, Q3

if __name__=="__main__":
    metric = 'NSE'
    run_dict = { 
                'lstm_training':
                    ['usa_time_split_nse_0908_233247',
                    'usa_time_split_nseLR_1308_113449',
                    'usa_time_split_mseLR_1308_131920'],
                'neuralhydrology':
                    [
                    'usa_time_split_nse_adaDT5_logQ3_1208_143346',
                    'usa_time_split_mse_adaDT5_logQ3_1308_113840'
                    ]
                }

    for model_dir, run_dirs in run_dict.items():
        if model_dir == 'lstm_training':
            model = 'LSTM'
            epoch = '35'
        else:
            model = 'coRNN'
            epoch = '35'

        for run_dir in run_dirs:
            parts = run_dir.split('_')
            exp_name = f"{model}: {parts[3]} {parts[4]} {parts[5]}"
            pct_nse_lt0, mean_nse_gt0, median_nse, nse_gt0_ci, Q1, Q3 = calc_metrics(model_dir, run_dir, epoch)
            print(exp_name)
            print(f'%_{metric}<0 : {pct_nse_lt0}%')
            print(f'Mean_{metric}>0 : {mean_nse_gt0}')
            print(f'95% CI: ({round(mean_nse_gt0 - nse_gt0_ci,3)}, {round(mean_nse_gt0 + nse_gt0_ci,3)})')
            print(f'Median {metric}: {median_nse}')
