#!/bin/bash

#SBATCH --job-name=usa_time_split_high-dt_mid-gamma_256-nhid_0907_101859_eval
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --time=0:15:00 # adjust as necessary
#SBATCH --mem-per-gpu=16GB # adjust as necessary
#SBATCH --mail-user=achiang@caltech.edu
#SBATCH --mail-type=BEGIN
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

set -euo pipefail # kill the job if anything fails
set -x # echo script
nh-run evaluate --run-dir /home/achiang/CliMA/Rivers/examples/catchment_models/neuralhydrology/runs/usa_time_split_high-dt_mid-gamma_256-nhid_0907_101859
echo done
