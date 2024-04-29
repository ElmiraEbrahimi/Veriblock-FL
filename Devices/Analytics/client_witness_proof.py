import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Load the data from the CSV file
client_data = pd.read_csv('final_analytics.csv')

# Convert memory usage from MB to GB for witness and proof
client_data['max_mem_compute_witness_avg_gb'] = client_data['max_mem_compute_witness_avg'] / 1024
client_data['max_mem_compute_witness_std_gb'] = client_data['max_mem_compute_witness_std'] / 1024
client_data['max_mem_generate_proof_avg_gb'] = client_data['max_mem_generate_proof_avg'] / 1024
client_data['max_mem_generate_proof_std_gb'] = client_data['max_mem_generate_proof_std'] / 1024

# Setting the context for the plot to 'paper' for academic paper style
sns.set_context("paper")

# Create a figure and a set of subplots
fig, ax = plt.subplots(figsize=(5, 5))

# Make the axes thicker
for axis in ['top','bottom','left','right']:
  ax.spines[axis].set_linewidth(2)

# Plot with error bars for memory usage during witness computation
ax.errorbar(client_data['batchsize'], client_data['max_mem_compute_witness_avg_gb'], 
             yerr=client_data['max_mem_compute_witness_std_gb'], fmt='-o', color='blue', 
             ecolor='darkblue', elinewidth=1.5, capsize=5, label='Compute witness')

# Plot with error bars for memory usage during proof generation
ax.errorbar(client_data['batchsize'], client_data['max_mem_generate_proof_avg_gb'], 
             yerr=client_data['max_mem_generate_proof_std_gb'], fmt='--X', color='red', 
             ecolor='darkred', elinewidth=3, capsize=5, label='Generate proof')

# Setting up plot labels and title
ax.set_xlabel('Batch sizes', fontsize=20, labelpad=10)
ax.set_ylabel('Max memory usage (GB)', fontsize=20, labelpad=10)
# ax.set_title('Maximum Memory Requirement for Client: Compute Witness vs. Generate Proof for Different Batch Sizes (GB)', fontsize=16, pad=20)

# Legend
legend_fontsize = 16
ax.legend(frameon=True, fontsize=legend_fontsize, markerscale=2)


# Restoring the grid lines for better readability
ax.grid(True)

# Make the tick labels larger
ax.tick_params(axis='both', which='major', labelsize=20)

# Save the plot to a file
plot_path = 'client_memory_usage_witness_proof.png'
fig.tight_layout()
fig.savefig(plot_path)

# Show plot
plt.show()

# Return the path for the saved plot
plot_path







