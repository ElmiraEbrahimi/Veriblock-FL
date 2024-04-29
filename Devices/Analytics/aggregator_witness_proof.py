import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import matplotlib.ticker as mtick

# Load the data from the CSV file
aggregator_data = pd.read_csv('aggregator_final_analytics.csv')

# Convert memory usage from MB to GB for witness and proof
aggregator_data['max_mem_compute_witness_avg_gb'] = aggregator_data['max_mem_compute_witness_avg'] / 1024
aggregator_data['max_mem_compute_witness_std_gb'] = aggregator_data['max_mem_compute_witness_std'] / 1024
aggregator_data['max_mem_generate_proof_avg_gb'] = aggregator_data['max_mem_generate_proof_avg'] / 1024
aggregator_data['max_mem_generate_proof_std_gb'] = aggregator_data['max_mem_generate_proof_std'] / 1024

# Setting the context for the plot to 'paper' for academic paper style
sns.set_context("paper")

# Create a figure and a set of subplots
fig, ax = plt.subplots(figsize=(5, 5))

# Make the axes thicker
for axis in ['top','bottom','left','right']:
  ax.spines[axis].set_linewidth(2)

# Plot with error bars for memory usage during witness computation
ax.errorbar(aggregator_data['client_number'], aggregator_data['max_mem_compute_witness_avg_gb'], 
             yerr=aggregator_data['max_mem_compute_witness_std_gb'], fmt='-o', color='blue', 
             ecolor='darkblue', elinewidth=3, capsize=5, label='Compute witness')

# Plot with error bars for memory usage during proof generation
ax.errorbar(aggregator_data['client_number'], aggregator_data['max_mem_generate_proof_avg_gb'], 
             yerr=aggregator_data['max_mem_generate_proof_std_gb'], fmt='--X', color='red', 
             ecolor='darkred', elinewidth=3, capsize=5, label='Generate proof')

# Setting up plot labels and title
ax.set_xlabel('Number of clients', fontsize=20, labelpad=10)
# ax.set_ylabel('Max Memory Usage (GB)', fontsize=14, labelpad=10)
# ax.set_title('Maximum Memory Requirement for Aggregator: Compute Witness vs. Generate Proof for Different Numbers of Clients (GB)', fontsize=16, pad=20)

# Legend
legend_fontsize = 16
ax.legend(frameon=True, fontsize=legend_fontsize, markerscale=2)

# Restoring the grid lines for better readability
ax.grid(True)

# Make the tick labels larger
ax.tick_params(axis='both', which='major', labelsize=20)
ax.yaxis.set_major_formatter(mtick.FormatStrFormatter('%.1f'))

# Save the plot to a file
plot_path = 'aggregator_witness_proof.png'
fig.tight_layout()
fig.savefig(plot_path)

# Show plot
plt.show()

# Return the path for the saved plot
plot_path







