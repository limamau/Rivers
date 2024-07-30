import sys
import torch

sys.path.append('/home/achiang/CliMA/Rivers/src/neuralhydrology/neuralhydrology/modelzoo')
from cudalstm import CudaLSTM

sys.path.append('/home/achiang/CliMA/Rivers/src/neuralhydrology/neuralhydrology/utils')
from config import Config

from pathlib import Path

run_dir = 'usa_time_split_adj_0807_170652'
run_path = Path(f'/home/achiang/CliMA/Rivers/examples/catchment_models/lstm_training/runs/{run_dir}/config.yml')
cfg = Config(run_path)

weight_file = f'runs/{run_dir}/model_epoch014.pt'
model = CudaLSTM(cfg=cfg)

model.load_state_dict(torch.load(weight_file))

for param_tensor in model.state_dict():
    print(f"{param_tensor}: {model.state_dict()[param_tensor].size()}")
    # if param_tensor == 'cell.c':
    #     c = model.state_dict()[param_tensor]
    #     print(param_tensor, "\t", c)
    #     sigma_hat = 1/6 + 1/6 * torch.tanh(c / 2)
    #     print(f'sigma_hat : {sigma_hat}')