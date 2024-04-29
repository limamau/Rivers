import pandas as pd
import os
import matplotlib.pyplot as plt

model_NSE = {}
run_dir = 'globe_basin_split_2404_220637'
split_name = 'Global Basin Split'
base_dir = os.path.join('/home/achiang/CliMA/Rivers/examples/catchment_models/training/runs', run_dir, 'validation')

for item in os.listdir(base_dir):
    if os.path.isdir(os.path.join(base_dir, item)) and item.startswith('model_epoch0'):
        dir_path = os.path.join(base_dir, item)
        epoch = dir_path[-2:]
        for file in os.listdir(dir_path):
            file_path = os.path.join(dir_path, file)
            if os.path.splitext(file_path)[1] == '.csv':
              df = pd.read_csv(file_path)
              model_NSE[int(epoch)] = df.NSE.median()

# Sort the dictionary by keys and extract x and y coordinates
x = sorted(model_NSE.keys())
y = [model_NSE[key] for key in x]

# Create a plot
plt.figure(figsize=(8, 5))  # Create a new figure window with a specified size
plt.plot(x, y, 'o-')  # Plot points connected by lines, with 'o' denoting the data points
plt.xlabel('Epoch')  # Label for x-axis
plt.ylabel('NSE')  # Label for y-axis
plt.title(split_name + ': Median NSE vs Epoch')  # Title of the plot
plt.grid(True)  # Enable grid for easier readability

# Optional: setting axis limits for better visualization
plt.xlim(min(x) - 1, max(x) + 1)
plt.ylim(min(y) - 0.1, max(y) + 0.1)

fig_path = os.path.join('/home/achiang/CliMA/Rivers/examples/catchment_models/training/runs', run_dir, 'validation/model_NSE_plot.png')
plt.savefig(fig_path, dpi=300)
