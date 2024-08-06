import sys
import torch
import numpy as np
import matplotlib.pyplot as plt

sys.path.append('/groups/esm/achiang/Rivers/src/neuralhydrology/neuralhydrology/modelzoo')
from cornn import coRNN

sys.path.append('/groups/esm/achiang/Rivers/src/neuralhydrology/neuralhydrology/utils')
from config import Config

from pathlib import Path

run_dir = 'usa_time_split_nse_adaDT5_0508_103715'
split = run_dir.split('_')
test_name = f'{split[3]} {split[4]}'
run_path = Path(f'/groups/esm/achiang/Rivers/examples/catchment_models/neuralhydrology/runs/{run_dir}/config.yml')
cfg = Config(run_path)

weight_file = f'runs/{run_dir}/model_epoch035.pt'
model = coRNN(cfg=cfg)

model.load_state_dict(torch.load(weight_file))

def create_histogram(tensor, name, edges):
    data = tensor.numpy()

    plt.figure()
    plt.hist(data, bins=edges, edgecolor='black')
    plt.title(f"{test_name}: {name}")
    plt.xlabel('Value')
    plt.ylabel('Frequency')
    plt.savefig(f"histograms/{name}.png")
    plt.close()

for param_tensor in model.state_dict():

    # print(f"{param_tensor}: {model.state_dict()[param_tensor].size()}")
    if param_tensor == 'cell.c':
        c = model.state_dict()[param_tensor]
        c_edges = np.arange(-6, 6.01, 0.2)
        create_histogram(c, f"c_hist_{split[3]}_{split[4]}", c_edges)

        dt_bound = 1/5
        sigma_hat = (dt_bound/2 + dt_bound/2 * torch.tanh(c / 2))
        sigma_edges = np.arange(0,dt_bound+0.01, 0.01)
        create_histogram(sigma_hat, f"sigma_hist_{split[3]}_{split[4]}", sigma_edges)