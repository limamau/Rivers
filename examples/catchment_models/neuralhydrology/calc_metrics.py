import os
import pandas as pd

def calc_metrics(model_dir, run_dir, epoch):
    path_to_csv = f'/home/achiang/CliMA/Rivers/examples/catchment_models/{model_dir}/runs/{run_dir}/test/model_epoch0{epoch}/test_metrics.csv'

    df = pd.read_csv(path_to_csv)
    df = df.dropna()

    nse = df['NSE']
    nse_lt0 = nse[nse < 0]
    nse_gt0 = nse[nse > 0]

    pct_nse_lt0 = round(100 * len(nse_lt0)/len(nse), 2)
    mean_nse_gt0 = round(nse_gt0.mean(), 2)
    median_nse = round(nse.median(), 2)

    return pct_nse_lt0, mean_nse_gt0, median_nse

if __name__=="__main__":
    run_dict = { 
                'neuralhydrology':
                    ['usa_time_split_512nhid_35epochs_1007_143728',
                    'usa_time_split_relu_1207_162102',
                    'usa_time_split_softplus_1207_162116']
                }

    for model_dir, run_dirs in run_dict.items():
        if model_dir == 'lstm_training':
            model = 'LSTM'
            epoch = '14'
        else:
            model = 'coRNN'
            epoch = '35'

        for run_dir in run_dirs:
            parts = run_dir.split('_')
            exp_name = f"{parts[3]}"
            pct_nse_lt0, mean_nse_gt0, median_nse = calc_metrics(model_dir, run_dir, epoch)
            print(exp_name)
            print(f'%_NSE<0 : {pct_nse_lt0}%')
            print(f'Mean_NSE>0 : {mean_nse_gt0}')
            print(f'Median : {median_nse} \n')