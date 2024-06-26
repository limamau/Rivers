import pickle
import matplotlib.pyplot as plt
from neuralhydrology.evaluation import metrics
import os

split_name = 'USA Time Split'
run_dir = 'usa_time_split_2606_152202'
epoch = '05'

# Load the CSV file
pickle_file = os.path.join(f'runs/{run_dir}/test/model_epoch0{epoch}/test_results.p')

with open(pickle_file, "rb") as fp:
    results = pickle.load(fp)

# print(results.keys())

# extract observations and simulations. First key is basin number
qobs = results['7050013170']['1D']['xr']['streamflow_obs']
qsim = results['7050013170']['1D']['xr']['streamflow_sim']

# plot figure
fig, ax = plt.subplots(figsize=(16,10))
ax.plot(qobs['date'], qobs, label='Observed')
ax.plot(qsim['date'], qsim, label='Simulated')
ax.legend()
ax.set_ylabel("Discharge (mm/d)")
ax.set_title(f"Test period - NSE {results['7050013170']['1D']['NSE']:.3f}")
plt.savefig(f"plots/{run_dir}_obs_vs_sim_{epoch}.png")

# print metrics
values = metrics.calculate_all_metrics(qobs.isel(time_step=-1), qsim.isel(time_step=-1))
for key, val in values.items():
    print(f"{key}: {val:.3f}")