import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Assuming the CSV files are in the same directory as your script
# Read the data from the CSV files
client_data = pd.read_csv('final_analytics.csv')
aggregator_data = pd.read_csv('aggregator_final_analytics.csv')

# Convert memory usage from MB to GB for both compilation and setup for client
client_data['max_mem_compile_avg_gb'] = client_data['max_mem_compile_avg'] / 1024
client_data['max_mem_compile_std_gb'] = client_data['max_mem_compile_std'] / 1024
client_data['max_mem_setup_avg_gb'] = client_data['max_mem_setup_avg'] / 1024
client_data['max_mem_setup_std_gb'] = client_data['max_mem_setup_std'] / 1024

# Convert memory usage from MB to GB for both compilation and setup for aggregator
aggregator_data['max_mem_compile_avg_gb'] = aggregator_data['max_mem_compile_avg'] / 1024
aggregator_data['max_mem_compile_std_gb'] = aggregator_data['max_mem_compile_std'] / 1024
aggregator_data['max_mem_setup_avg_gb'] = aggregator_data['max_mem_setup_avg'] / 1024
aggregator_data['max_mem_setup_std_gb'] = aggregator_data['max_mem_setup_std'] / 1024

# Setting the context for the plot to 'paper' for academic paper style
sns.set_context("paper")

# Create a figure with two subplots, sharing the x-axis but not y-axis
# fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 6))
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 6))

# Make the axes thicker
for axis in ['top','bottom','left','right']:
    ax1.spines[axis].set_linewidth(2)
    ax2.spines[axis].set_linewidth(2)

# Plot with error bars for memory usage during compilation and setup for clients
ax1.errorbar(client_data['batchsize'], client_data['max_mem_compile_avg_gb'], 
             yerr=client_data['max_mem_compile_std_gb'], fmt='-o', color='blue', 
             ecolor='darkblue', elinewidth=3, capsize=5, label='Compilation')
ax1.errorbar(client_data['batchsize'], client_data['max_mem_setup_avg_gb'], 
             yerr=client_data['max_mem_setup_std_gb'], fmt='--X', color='red', 
             ecolor='darkred', elinewidth=3, capsize=5, label='Setup')

# Plot with error bars for memory usage during compilation and setup for the aggregator
ax2.errorbar(aggregator_data['client_number'], aggregator_data['max_mem_compile_avg_gb'], 
             yerr=aggregator_data['max_mem_compile_std_gb'], fmt='-o', color='blue', 
             ecolor='darkblue', elinewidth=3, capsize=5, label='Compilation')
ax2.errorbar(aggregator_data['client_number'], aggregator_data['max_mem_setup_avg_gb'], 
             yerr=aggregator_data['max_mem_setup_std_gb'], fmt='--X', color='red', 
             ecolor='darkred', elinewidth=3, capsize=5, label='Setup')

# Set labels and titles for the first plot (client)
ax1.set_xlabel('Batch Sizes', fontsize=20, labelpad=10)
ax1.set_ylabel('Max Memory Usage (GB)', fontsize=20, labelpad=10)
ax1.set_title('Client Circuit', fontsize=20, pad=10)

# Set labels and titles for the second plot (aggregator)
ax2.set_xlabel('Number of Clients', fontsize=20, labelpad=10)
ax2.set_title('Aggregator Circuit', fontsize=20, pad=10)

# Set the legend with a larger font size and scaled-up markers
legend_fontsize = 16
ax1.legend(frameon=True, fontsize=legend_fontsize, markerscale=2)
ax2.legend(frameon=True, fontsize=legend_fontsize, markerscale=2)

# Restoring grid lines for better readability
ax1.grid(True)
ax2.grid(True)

# Make tick labels larger
ax1.tick_params(axis='both', which='major', labelsize=20)
ax2.tick_params(axis='both', which='major', labelsize=20)

# Adjust y-axis scale for aggregator to be different from client
ax2.set_ylim(0, max(aggregator_data[['max_mem_compile_avg_gb', 'max_mem_setup_avg_gb']].max()) * 1.1)

# Save the plot to a file
combined_plot_path = 'combined_compile_setup.pdf'

fig.tight_layout()
fig.savefig(combined_plot_path)

# Show plot
plt.show()