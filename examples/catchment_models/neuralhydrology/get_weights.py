import sys
import torch
import numpy as np
import matplotlib.pyplot as plt

sys.path.append('/groups/esm/achiang/Rivers/src/neuralhydrology/neuralhydrology/modelzoo')
from cornn import coRNN

sys.path.append('/groups/esm/achiang/Rivers/src/neuralhydrology/neuralhydrology/utils')
from config import Config

from pathlib import Path

run_dir = 'usa_time_split_nseMse_adaDT1_0108_121334'
run_path = Path(f'/groups/esm/achiang/Rivers/examples/catchment_models/neuralhydrology/runs/{run_dir}/config.yml')
cfg = Config(run_path)

weight_file = f'runs/{run_dir}/model_epoch035.pt'
model = coRNN(cfg=cfg)

model.load_state_dict(torch.load(weight_file))

for param_tensor in model.state_dict():

    # print(f"{param_tensor}: {model.state_dict()[param_tensor].size()}")
    if param_tensor == 'cell.c':
        c = model.state_dict()[param_tensor]
        # hist, bin_edges = np.histogram(c, bins=25)

        # plt.figure(1)
        # plt.hist(hist, bins=bin_edges, edgecolor='black')
        # plt.title('Histogram of c')
        # plt.xlabel('c')
        # plt.ylabel('Frequency')
        # plt.savefig("c_histogram.png")
        # plt.close()

        print(param_tensor, "\t", c)
        sigma_hat = 1/12 + 1/12 * torch.tanh(c / 2)
        hist, bin_edges = torch.histogram(sigma_hat, bins = 25)
        print(f'sigma_hat : {sigma_hat}')
        # hist, bin_edges2 = np.histogram(sigma_hat, bins=2)

        plt.figure()
        plt.hist(hist, bins=bin_edges, edgecolor='black')
        plt.title('Histogram of sigma')
        plt.xlabel('sigma')
        plt.ylabel('Frequency')
        plt.savefig("sigma_histogram.png")
        plt.close()