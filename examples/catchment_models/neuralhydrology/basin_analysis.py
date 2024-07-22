import pickle
import matplotlib.pyplot as plt
from neuralhydrology.evaluation import metrics
import os

# Load the CSV file
pickle_file = os.path.join(f'/home/achiang/CliMA/Rivers/examples/catchment_models/neuralhydrology/runs/usa_time_split_512nhid_35epochs_1007_143728/test/model_epoch035/test_results.p')

with open(pickle_file, "rb") as fp:
    results = pickle.load(fp)

all_qobs = {}
for basin_id in results.keys():
    all_qobs[basin_id] = results[basin_id]['1D']['xr']['streamflow_obs']


fig, ax = plt.subplots(figsize=(16,10))
for basin_id, qobs in all_qobs.items():
    ax.plot(qobs['date'], qobs, label='basin_id')
# ax.legend()
ax.set_ylabel("Discharge (mm/d)")
ax.set_title(f"All Basins")
if not os.path.exists(f'plots/all_basins'):
    os.makedirs(f'plots/all_basins')

fig_path = f'plots/all_basins/obs_basins.png'
plt.savefig(fig_path, dpi=300)
plt.close()