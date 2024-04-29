import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns

# Apply a more subtle and academic color scheme
sns.set_context("paper")

# Real data
batch_sizes = [10, 20, 30, 40]
on_chain_gas_units = np.array([ 2264623, 2340599,  2364371,  2398739]) / 1e6  # Converted to millions
off_chain_agg_gas_units = np.array([386944, 386944, 386944, 386944]) / 1e6  # Converted to millions
off_training_gas_units = np.array([432826, 432826, 432826, 432826]) / 1e6  # Converted to millions

# Define a more subtle color scheme
colors = {
    'on_chain': '#d62728',  # a lighter red
    'off_training': '#1f77b4',  # a muted blue
    'off_chain_agg': '#2ca02c',  # a muted green
}

# Initialize the figure
plt.figure(figsize=(7, 4))

# Width of the bars
bar_width = 0.2

# Set the positions of the bars
positions = np.arange(len(batch_sizes))

# Plot the bars
plt.bar(positions - bar_width, on_chain_gas_units, width=bar_width, label='On-chain aggregation', color=colors['on_chain'])
plt.bar(positions, off_training_gas_units, width=bar_width, label='Off-chain training', color=colors['off_training'])
plt.bar(positions, off_chain_agg_gas_units, bottom=off_training_gas_units, width=bar_width, label='Off-chain aggregation', color=colors['off_chain_agg'])

# Customizing the plot
plt.xlabel('Batch sizes', fontsize=14)  # Increase font size for x-axis label
plt.ylabel('MGas', fontsize=14)  # Increase font size for y-axis label
plt.xticks(positions - bar_width / 2, batch_sizes, fontsize=12)  # Increase font size for x-axis ticks
plt.yticks(fontsize=14)  # Increase font size for y-axis ticks

# Adjusting the legend
# plt.legend(fontsize=10, loc='upper left')  # Increase font size for legend
plt.legend(fontsize=11, loc='lower center', bbox_to_anchor=(0.5, 1), ncol=3, frameon=False)

# Adjust the figure layout to make room for the legend
plt.subplots_adjust(top=0.4)


# Add gridlines behind the bars
plt.grid(True, which='both', axis='y', linestyle='--', linewidth=0.5)
plt.grid(True, which='major', axis='x', linestyle='--', linewidth=0.5)

# Bring bars to the front
plt.gca().set_axisbelow(False)

# Scientific notation for y-axis
plt.ticklabel_format(style='sci', axis='y', scilimits=(0,0))

plt.tight_layout()

# Save the figure as a PDF
pdf_plot_path = 'gas_units_chart_with_larger_legend.pdf'
plt.savefig(pdf_plot_path, format='pdf')

# Show the plot
plt.show()
