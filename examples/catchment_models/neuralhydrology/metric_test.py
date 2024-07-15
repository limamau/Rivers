import pickle
import matplotlib.pyplot as plt
from neuralhydrology.evaluation import metrics
import os
from typing import Dict, List, Tuple
from xarray.core.dataarray import DataArray
import pandas as pd

def _validate_inputs(obs: DataArray, sim: DataArray):
    if obs.shape != sim.shape:
        raise RuntimeError("Shapes of observations and simulations must match")

    if (len(obs.shape) > 1) and (obs.shape[1] > 1):
        raise RuntimeError("Metrics only defined for time series (1d or 2d with second dimension 1)")

def _mask_valid(obs: DataArray, sim: DataArray) -> Tuple[DataArray, DataArray]:
    # mask of invalid entries. NaNs in simulations can happen during validation/testing
    idx = (~sim.isnull()) & (~obs.isnull())

    if idx.shape != obs.shape:
        raise RuntimeError("Shapes of mask and observations must match")

    obs = obs.where(idx, drop=True)
    sim = sim.where(idx, drop=True)

    return obs, sim

def calc_metrics(path_to_csv):
    df = pd.read_csv(path_to_csv)
    df = df.dropna()

    nse = df['NSE']
    nse_lt0 = nse[nse < 0]
    nse_gt0 = nse[nse > 0]

    pct_nse_lt0 = round(100 * len(nse_lt0)/len(nse), 2)
    mean_nse_gt0 = round(nse_gt0.mean(), 2)
    median_nse = round(nse.median(), 2)

    return pct_nse_lt0, mean_nse_gt0, median_nse

def cdf_plot(path_to_csv):
    # Load the CSV file
    df = pd.read_csv(path_to_csv)

    # Sort the data by NSE
    df = df.sort_values('NSE')

    # Calculate the CDF values
    cdf = df['NSE'].rank(method='first', pct=True)

    return df['NSE'], cdf


if __name__ == '__main__':
    # model_dir = 'neuralhydrology'
    # run_dir = 'usa_time_split_512nhid_35epochs_1007_143728'
    # epoch = '35'

    # # Load the p file
    # pickle_file = os.path.join(f'/home/achiang/CliMA/Rivers/examples/catchment_models/{model_dir}/runs/{run_dir}/test/model_epoch0{epoch}/test_results.p')

    # with open(pickle_file, "rb") as fp:
    #     results = pickle.load(fp)
    
    # data = []

    # for basin_id in results.keys():
    #     # extract observations and simulations. First key is basin number
    #     qobs = results[basin_id]['1D']['xr']['streamflow_obs']
    #     qsim = results[basin_id]['1D']['xr']['streamflow_sim']

    #     _validate_inputs(qobs, qsim)

    #     # get time series with only valid observations
    #     qobs, qsim = _mask_valid(qobs, qsim)

    #     # make all negative values 0
    #     qsim = qsim.where(qsim > 0, 0)

    #     # calc NSE
    #     denominator = ((qobs - qobs.mean())**2).sum()
    #     numerator = ((qsim - qobs)**2).sum()

    #     nse = 1 - numerator / denominator

    #     data.append([basin_id, float(nse)])
    
    # #create CSV
    # df = pd.DataFrame(data, columns=['basin', 'NSE'])
    # df.to_csv('test_metrics_adj.csv', index=False)

    # calculate metrics
    paths = {
            'adj coRNN': 'neuralhydrology/test_metrics_adj.csv',
            'coRNN' : 'neuralhydrology/runs/usa_time_split_512nhid_35epochs_1007_143728/test/model_epoch035/test_metrics.csv',
            'LSTM' : 'lstm_training/runs/usa_time_split_adj_0807_170652/test/model_epoch014/test_metrics.csv'
            }

    CDF = []
    for exp_name, path_to_csv in paths.items():
        abs_path = f'/home/achiang/CliMA/Rivers/examples/catchment_models/{path_to_csv}'
        pct_nse_lt0, mean_nse_gt0, median_nse = calc_metrics(abs_path)
        
        print(exp_name)
        print(f'%_NSE<0 : {pct_nse_lt0}%')
        print(f'Mean_NSE>0 : {mean_nse_gt0}')
        print(f'Median : {median_nse} \n')
        
        nse, cdf = cdf_plot(abs_path)
        CDF.append((nse, cdf, exp_name))
    
    plot_folder = 'neg_traj'
    if not os.path.exists(f'plots/{plot_folder}'):
        os.makedirs(f'plots/{plot_folder}')

    plt.figure(1)
    for (nse, cdf, exp_name) in CDF:
        plt.plot(nse, cdf, label=exp_name)
    plt.xlabel('NSE')
    plt.ylabel('CDF')
    plt.title(f'USA time split: CDF of NSE')
    plt.xlim(0,1)
    plt.ylim(-0.1,1.1)
    plt.grid(True)
    plt.legend()
    fig_path = f'plots/{plot_folder}/CDF_NSE.png'
    plt.savefig(fig_path, dpi=300)
    plt.close()