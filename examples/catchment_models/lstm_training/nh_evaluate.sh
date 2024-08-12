#!/bin/bash

#SBATCH --job-name=usa_time_split_nse_0908_233247
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --gres=gpu:1 # remove :v100 for p100    
#SBATCH --time=0:15:00 # adjust as necessary
#SBATCH --mem-per-gpu=16GB # adjust as necessary
#SBATCH --mail-user=achiang@caltech.edu
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

set -euo pipefail # kill the job if anything fails
set -x # echo script
nh-run evaluate --run-dir /groups/esm/achiang/Rivers/examples/catchment_models/lstm_training/runs/usa_time_split_nse_0908_233247
echo done