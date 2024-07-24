import pickle
import matplotlib.pyplot as plt
from neuralhydrology.evaluation import metrics
import os

def obs_vs_sim_plot(model_dir, run_dir, epoch, basin_id = '7050039160', plot_bool = False):
    parts = run_dir.split('_')
    split_name = f"{parts[0].upper()} {parts[1].capitalize()} {parts[2].capitalize()}"

    # Load the CSV file
    pickle_file = os.path.join(f'/home/achiang/CliMA/Rivers/examples/catchment_models/{model_dir}/runs/{run_dir}/test/model_epoch0{epoch}/test_results.p')

    with open(pickle_file, "rb") as fp:
        results = pickle.load(fp)
    
    # extract observations and simulations. First key is basin number
    qobs = results[basin_id]['1D']['xr']['streamflow_obs']
    qsim = results[basin_id]['1D']['xr']['streamflow_sim']

    if plot_bool:
        # plot figure
        fig, ax = plt.subplots(figsize=(16,10))
        # ax.plot(qobs['date'], qobs, label='Observed')
        ax.plot(qsim['date'][3*365 + 200:4*365], qsim[3*365 + 200:4*365], label='Simulated')
        ax.legend()
        ax.set_ylabel("Discharge (mm/d)")
        ax.set_title(f"Test period - NSE {results[basin_id]['1D']['NSE']:.3f}")
        ax.set_ylim(93, 94)
        if not os.path.exists(f'plots/{run_dir}'):
            os.makedirs(f'plots/{run_dir}')

        fig_path = f'plots/{run_dir}/obs_vs_sim_{epoch}.png'
        plt.savefig(fig_path, dpi=300)
        plt.close()

    return qobs, qsim

    # print metrics
    # values = metrics.calculate_all_metrics(qobs.isel(time_step=-1), qsim.isel(time_step=-1))
    # for key, val in values.items():
    #     print(f"{key}: {val:.3f}")

if __name__ == '__main__':
    qobs, qsim = obs_vs_sim_plot('neuralhydrology', 'usa_time_split_512nhid_positive_1807_121830', '35', basin_id = '7050039160', plot_bool = True)
    print(qsim)
    # qsim.dropna
    # # min_sim = min(qsim)

    # print(f"qsim: {qsim}\n")
    # print(f"min_qsim: {qsim.min()}\n")
    # print(f"qsim size: {qsim.size}")

    # qmin = qsim.min()

    # # count = 0
    # for s in qsim:
    #     print(s)
        # if s.values == qsim.min():
        #     count += 1
    
    # print(count)
        
    # mask = (qsim == min_sim)
    # print(f"count: {len(qsim == min_sim)}")