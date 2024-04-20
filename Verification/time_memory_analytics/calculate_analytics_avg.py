import pandas as pd

def calculate_averages_and_stds(input_file, output_file):
    df = pd.read_csv(input_file)

    averages = df.mean().round(2)  # Round averages to 2 decimal 
    stds = df.std().round(2)   


    results_df = pd.DataFrame()

    # Append averages and standard deviations to the results DataFrame 
    for col in df.columns:
        results_df[str(col) + '_avg'] = [averages[col]]
        results_df[str(col) + '_std'] = [stds[col]]

    
    results_df.to_csv(output_file, index=False)


input_csv = 'analytics.csv'  # The file should be in the same directory
output_csv = 'time_avg_std.csv'  # The result will be saved in the same directory

calculate_averages_and_stds(input_csv, output_csv)