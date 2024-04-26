#!/bin/bash

#SBATCH --job-name=globe_basin_split
#SBATCH --output=/home/achiang/CliMA/Rivers/training_out_files/%j.out
#SBATCH --error=/home/achiang/CliMA/Rivers/training_err_files/%j.err
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --tasks-per-node=1
#SBATCH --gres=gpu:v100:1 # remove :v100 for p100    
#SBATCH --time=9:00:00 # adjust as necessary
#SBATCH --mem-per-gpu=16GB # adjust as necessary
#SBATCH --mail-user=achiang@caltech.edu
#SBATCH --mail-type=END
#SBATCH --mail-type=FAIL

set -euo pipefail # kill the job if anything fails
set -x # echo script
nh-run train --config-file /home/achiang/CliMA/Rivers/examples/catchment_models/training/globe_basin_split.yml #nh-run ...?
echo done
