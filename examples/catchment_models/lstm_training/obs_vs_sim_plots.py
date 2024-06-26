import pickle
import matplotlib.pyplot as plt
from neuralhydrology.evaluation import metrics

with open("runs/usa_time_split_2606_152202/test/model_epoch005/test_results.p", "rb") as fp:
    results = pickle.load(fp)

# print(results.keys())

# extract observations and simulations
qobs = results['7050013170']['1D']['xr']['streamflow_obs']
qsim = results['7050013170']['1D']['xr']['streamflow_sim']

# plot figure
fig, ax = plt.subplots(figsize=(16,10))
ax.plot(qobs['date'], qobs, label='Observed')
ax.plot(qsim['date'], qsim, label='Simulated')
ax.legend()
ax.set_ylabel("Discharge (mm/d)")
ax.set_title(f"Test period - NSE {results['7050013170']['1D']['NSE']:.3f}")
plt.savefig("runs/usa_time_split_2606_152202/test/obs_vs_sim.png")

# print metrics
values = metrics.calculate_all_metrics(qobs.isel(time_step=-1), qsim.isel(time_step=-1))
for key, val in values.items():
    print(f"{key}: {val:.3f}")