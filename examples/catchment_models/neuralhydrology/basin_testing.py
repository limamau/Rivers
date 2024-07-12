import os
import pandas as pd

def get_df(model_dir, run_dir, epoch):
    path_to_csv = f'/home/achiang/CliMA/Rivers/examples/catchment_models/{model_dir}/runs/{run_dir}/test/model_epoch0{epoch}/test_metrics.csv'

    df = pd.read_csv(path_to_csv)
    df = df.dropna()
    return df


if __name__=="__main__":
    df_lstm = get_df('lstm_training', 'usa_time_split_adj_0807_170652','14')
    df_cornn = get_df('neuralhydrology', 'usa_time_split_512nhid_35epochs_1007_143728', '35')

    #remove rows with positive NSE
    df_lstm_poor = df_lstm[df_lstm['NSE'] < 0] 
    df_cornn_poor = df_cornn[df_cornn['NSE'] < 0] 

    # Find common poor performing basins
    lstm_set = set(df_lstm_poor['basin'])
    cornn_set = set(df_cornn_poor['basin'])

    common_basins = lstm_set & cornn_set

    print(f'# poor performing basins for LSTM: {len(lstm_set)}')
    print(f'# poor performing basins for coRNN: {len(cornn_set)}')
    print(f'# common poor performing basins: {len(common_basins)}')

    lstm_only = lstm_set - cornn_set
    cornn_only = cornn_set - lstm_set

    df_cornn_w_poor_lstm = df_cornn[df_cornn['basin'].isin(lstm_only)]
    df_lstm_w_poor_cornn = df_lstm[df_lstm['basin'].isin(cornn_only)]

    print(f'Mean coRNN NSE for poor performing LSTM basins: {df_cornn_w_poor_lstm["NSE"].mean():.2f}')
    print(f'Mean LSTM NSE for poor performing coRNN basins: {df_lstm_w_poor_cornn["NSE"].mean():.2f}')

    med_lstm = df_lstm['NSE'].median()
    med_cornn = df_cornn['NSE'].median()

    df_cornn_gt_med = df_cornn_w_poor_lstm[df_cornn_w_poor_lstm['NSE'] >= med_cornn]
    df_lstm_gt_med = df_lstm_w_poor_cornn[df_lstm_w_poor_cornn['NSE'] >= med_lstm]

    print(f"# basins with coRNN NSE > median NSE: {len(df_cornn_gt_med['basin'])}")
    print(f"# basins with LSTM NSE > median NSE: {len(df_lstm_gt_med['basin'])}")

    print(df_lstm_gt_med)

