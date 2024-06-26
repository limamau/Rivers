import pandas as pd
import matplotlib.pyplot as plt
import os

split_name = 'USA Time Split'
run_dir = 'usa_time_split_2606_124027'
epoch = '05'

# Load the CSV file
csv_path = os.path.join(f'runs/{run_dir}/test/model_epoch0{epoch}/test_metrics.csv')
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
plt.title(f'{split_name}: CDF of NSE for {epoch} epochs')
plt.xlim(0,1)
plt.grid(True)

fig_path = os.path.join(f'plots/{run_dir}_CDF_NSE_{epoch}.png')
plt.savefig(fig_path, dpi=300)
