import sys
import torch

sys.path.append('/groups/esm/achiang/Rivers/src/neuralhydrology/neuralhydrology/modelzoo')
from cornn import coRNN

sys.path.append('/groups/esm/achiang/Rivers/src/neuralhydrology/neuralhydrology/utils')
from config import Config

from pathlib import Path

run_dir = 'usa_time_split_nse_adaDT1_3107_125025'
run_path = Path(f'/groups/esm/achiang/Rivers/examples/catchment_models/neuralhydrology/runs/{run_dir}/config.yml')
cfg = Config(run_path)

weight_file = f'runs/{run_dir}/model_epoch035.pt'
model = coRNN(cfg=cfg)

model.load_state_dict(torch.load(weight_file))

for param_tensor in model.state_dict():

    # print(f"{param_tensor}: {model.state_dict()[param_tensor].size()}")
    if param_tensor == 'cell.c':
        c = model.state_dict()[param_tensor]
        print(param_tensor, "\t", c)
        sigma_hat = 1/12 + 1/12 * torch.tanh(c / 2)
        print(f'sigma_hat : {sigma_hat}')