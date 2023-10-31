import pickle
from pathlib import Path
import numpy as np
import torch
from neuralhydrology.evaluation import metrics
from neuralhydrology.nh_run import start_run, eval_run
from tqdm import tqdm
import pandas as pd
import argparse

# Create an argument parser
parser = argparse.ArgumentParser(description="Simulate for a specific topological level in basins.txt")

# Add arguments for 'epoch' and 'model_dir'
parser.add_argument("--epoch", type=int, help="Epoch value")
parser.add_argument("--model_dir", type=str, help="Model directory path")
parser.add_argument("--hydro_lv", type=str, help="HydroSHEDS level")

# Parse the command-line arguments
args = parser.parse_args()

# Assign the values of 'epoch' and 'model_dir' to variables
epoch = args.epoch
model_dir = args.model_dir
hydro_lv = args.hydro_lv

# run directory
run_dir = Path(model_dir)

# directory to save simulations
output_dir = Path("/central/scratch/mdemoura/Rivers/complete_simulation/simulations/simulations_lv{}".format(hydro_lv))

# evaluates and saves test data
eval_run(run_dir=run_dir, period="test", epoch=epoch)

# open test results
with open(run_dir / "test" / "model_epoch0{}".format(epoch) / "test_results.p", "rb") as fp:
    results = pickle.load(fp)
    
# itarate over all the simulated basins
for basin in tqdm(results.keys()):
    qsim = results[basin]['1D']['xr']['streamflow_sim']

    # save dataframe
    df = pd.DataFrame({'date': qsim["date"].values, 'sim': qsim.values.flatten()})
    df.to_csv(output_dir / "basin_{}.csv".format(basin), index=False)