import pandas as pd
import matplotlib.pyplot as plt
import os

split_name = 'Global Basin Split'
run_dir = 'globe_basin_split_2404_220637'

# Load the CSV file
csv_path = os.path.join('/home/achiang/CliMA/Rivers/examples/catchment_models/training/runs', run_dir, 'test/model_epoch035/test_metrics.csv')
df = pd.read_csv(csv_path)

# Sort the data by NSE
df = df.sort_values('NSE')

# Calculate the CDF values
cdf = df['NSE'].rank(method='first', pct=True)

# Plotting the CDF
plt.figure(figsize=(8, 6))
plt.plot(df['NSE'], cdf)
plt.xlabel('NSE')
plt.ylabel('CDF')
plt.title(split_name + ': CDF of NSE')
plt.xlim(0,1)
plt.grid(True)

fig_path = os.path.join('/home/achiang/CliMA/Rivers/examples/catchment_models/training/runs', run_dir, 'test/CDF_NSE.png')
plt.savefig(fig_path, dpi=300)
