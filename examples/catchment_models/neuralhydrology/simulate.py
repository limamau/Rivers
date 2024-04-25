import pickle
from pathlib import Path
from tqdm import tqdm
import pandas as pd
from neuralhydrology.evaluation import metrics

def save_metrics(results, metrics_file):
    # list to store NSE values from predictions
    basin_column = []
    nse_column = []
    pearsonr_column = []
    kge_column = []

    # calculate values in each list
    for basin_id in results.keys():
        if len(results[basin_id]['1D']) == 2:
            qobs = results[basin_id]['1D']['xr']['streamflow_obs']
            qsim = results[basin_id]['1D']['xr']['streamflow_sim']
            nse = metrics.nse(qobs.isel(time_step=-1), qsim.isel(time_step=-1))
            pearsonr = metrics.pearsonr(qobs.isel(time_step=-1), qsim.isel(time_step=-1))
            kge = metrics.kge(qobs.isel(time_step=-1), qsim.isel(time_step=-1))
            basin_column.append(basin_id)
            nse_column.append(nse)
            pearsonr_column.append(pearsonr)
            kge_column.append(kge)

    # save dataframe
    df = pd.DataFrame({'basin': basin_column, 'nse': nse_column, 'pearsonr': pearsonr_column, 'kge': kge_column})
    df.to_csv(metrics_file, index=False)
    
def save_simulations(results, simulations_dir):
    # iterate over all the simulated basins
    for basin in tqdm(results.keys()):
        qobs = results[basin]['1D']['xr']['streamflow_obs']
        qsim = results[basin]['1D']['xr']['streamflow_sim']

        # save dataframe
        df = pd.DataFrame({'date': qobs["date"].values, 'obs': qobs.values.flatten(), 'sim': qsim.values.flatten()})
        df.to_csv(simulations_dir + 'basin_{}.csv'.format(basin), index=False)

def main():
    # Get the parent directory of the script file
    script_dir = Path(__file__).parent
    
    # This is created after training a model
    run_dir = script_dir / "runs" / "model_id" # to be filled
    
    # This is created after evaluating a model
    with open(run_dir / "test" / "model_epoch0XX" / "test_results.p", "rb") as fp: # to be filled
        results = pickle.load(fp)
        
    # Metrics - this creates one csv file with all the metrics for all the basins
    metrics_file = "path" / "to" / "metrics.csv" # to be filled
    save_metrics(results, run_dir, metrics_file)
    
    # Simulations - this creates one csv file per basin with the simulated and observed values
    simulations_dir = "path" / "to" / "simulations" # to be filled
    save_simulations(results, simulations_dir)
    
if __name__ == '__main__':
    main()