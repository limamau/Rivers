import sys
import torch

sys.path.append('/home/achiang/CliMA/Rivers/src/neuralhydrology/neuralhydrology/modelzoo')
from cornn import coRNN

sys.path.append('/home/achiang/CliMA/Rivers/src/neuralhydrology/neuralhydrology/utils')
from config import Config

from pathlib import Path

run_dir = 'usa_time_split_512nhid_positive_1807_121830'
run_path = Path(f'/home/achiang/CliMA/Rivers/examples/catchment_models/neuralhydrology/runs/{run_dir}/config.yml')
cfg = Config(run_path)

weight_file = f'runs/{run_dir}/model_epoch035.pt'
model = coRNN(cfg=cfg)

model.load_state_dict(torch.load(weight_file))

for param_tensor in model.state_dict():
    print(f"{param_tensor}: {model.state_dict()[param_tensor]}")
    # if param_tensor == 'cell.c':
    #     c = model.state_dict()[param_tensor]
    #     print(param_tensor, "\t", c)
    #     sigma_hat = 1/6 + 1/6 * torch.tanh(c / 2)
    #     print(f'sigma_hat : {sigma_hat}')