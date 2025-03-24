#!/usr/bin/env python

from matplotlib.legend import Legend
import matplotlib.pyplot as plt
import pandas as pd
from pandas import DataFrame
import seaborn as sns


SETTINGS = ["host.direct", "host.proxied", "enclave.proxied", "host.cross_instance", "enclave.cross_instance"]
SETTING_IDs = ["LL", "LLP", "LNE", "N", "NNE"]
SETTING_COLORS = ["Without Nitro Enclaves", "Without Nitro Enclaves", "With Nitro Enclaves", "Without Nitro Enclaves", "With Nitro Enclaves"]

DATA_DIR = "../results/data"
IMG_DIR = "../results/img"

def main():
    df = pd.read_csv(f"{DATA_DIR}/results.csv")

    print(df.columns)

    # Filter to required results
    df = df[(df["num_clients"] == 10)
            & (df["pipeline"] == 3)
            #& (df["instance_type"] == "c6in.16xlarge")
            & (df["op"] == "SET")
            #& (df["proxy_reuse_depth"] == 31)
            & ~(df["proxy_reuse_depth"].isin([1,10]))
            & ~((df["instance_type"] == "c6in.16xlarge") & (df["setup"] == "direct") )
            ]

    df.to_csv(f"{DATA_DIR}/filtered.csv", index=False)

    x_axis = "Setting"
    y_axis_1 = "Throughput [ops/s]"
    y_axis_2 = "Latency [ms]"
    hue = "Color"

    settings = df["context"] + "." + df["setup"]
    setting_names = settings.replace({x: y for x,y in zip(SETTINGS, SETTING_IDs)})
    setting_colors = settings.replace({x: y for x,y in zip(SETTINGS, SETTING_COLORS)})

    data_throughput = DataFrame()
    data_throughput[x_axis] = setting_names
    data_throughput[y_axis_1] = df["rps"]
    data_throughput[hue] = setting_colors

    data_latency = DataFrame()
    data_latency[x_axis] = setting_names
    data_latency[y_axis_2] = df["p50_latency_ms"]
    data_latency[hue] = setting_colors

    aggregated = data_throughput.groupby(x_axis)[y_axis_1].mean()
    aggregated_latency = data_latency.groupby(x_axis)[y_axis_2].mean()
    counts = data_throughput.groupby(x_axis).count()

    print(counts.to_string())

    print(f"Relative throughput with proxy: {aggregated.loc['LLP'] / aggregated.loc['LL']}")
    print(f"Relative latency with proxy: {aggregated_latency.loc['LLP'] / aggregated_latency.loc['LL']}")
    print(f"Relative throughput local compared to proxy: {aggregated.loc['LNE'] / aggregated.loc['LLP']}")
    print(f"Relative latency local compared to proxy: {aggregated_latency.loc['LNE'] / aggregated_latency.loc['LLP']}")
    print(f"Relative throughput network compared to LL: {aggregated.loc['N'] / aggregated.loc['LL']}")
    print(f"Relative latency network compared to LL: {aggregated_latency.loc['N'] / aggregated_latency.loc['LL']}")
    print(f"Relative throughput enclave network: {aggregated.loc['NNE'] / aggregated.loc['N']}")
    print(f"Relative latency enclave network: {aggregated_latency.loc['NNE'] / aggregated_latency.loc['N']}")

    # Set figure stile
    sns.set_style("ticks")
    sns.set_palette("deep")
    sns.set_context("notebook")

    blue = sns.color_palette()[0]
    green = sns.color_palette()[2]

    palette = [blue, blue, green, blue, green]

    f, (ax1, ax2) = plt.subplots(figsize=(6,2.5),
        ncols=2, sharey=False)
    sns.barplot(data=data_throughput, y=y_axis_1, x=x_axis,
        order=SETTING_IDs,
        hue=hue,
        hue_order=SETTING_COLORS,
        palette=palette,
        ax=ax1,
        legend=False)
    sns.barplot(data=data_latency, y=y_axis_2, x=x_axis,
        order=SETTING_IDs,
        hue=hue,
        hue_order=SETTING_COLORS,
        palette=palette,
        ax=ax2,
        legend=True)

    ax1.set_ylim(bottom=0, top=500_000)
    ax2.set_ylim(bottom=0, top=2)

    sns.move_legend(ax2, "lower center", frameon=False, bbox_to_anchor=(-0.1, 0.95), ncols=2, title=None)

    for ax in (ax1, ax2):
        ax.grid(axis="y")
        plt.text(0.3, 0.93, "Local", ha='center', va='center', transform=ax.transAxes)
        plt.text(0.8, 0.93, "Network", ha='center', va='center', transform=ax.transAxes)

        ax.axvline(x=2.5, color='black', linestyle='--', linewidth=1)

    plt.tight_layout(pad=0.5)
    plt.subplots_adjust(wspace=0.32)

    plt.savefig(f"{IMG_DIR}/redis_throughput_latency_10_3.pdf", dpi=600)


if __name__ == '__main__':
    main()
