#!/usr/bin/env python

import matplotlib.pyplot as plt
import pandas as pd
from pandas import DataFrame
import seaborn as sns
from pathlib import Path


UNITS = ["", "k", "M"]
TICKS = [str(num) + unit for unit in UNITS for num in [2**x for x in range(10)]]
SETTING_IDs = [1, 3, 2, 4, 5]
SETTINGS = ["LL", "LLP", "LNE", "N", "NNE"]
DATA_DIR = "../results/data"
IMG_DIR = "../results/img"

def plot_paper():
    df = pd.read_csv(f"{DATA_DIR}/results.csv")

    # Filter to required results
    df = df[(df["client.msg_size"] == 8)
            & (df["instance_type"] == "c6in.8xlarge")
            & (df["server.rsp_size"] >= 64)
            & (df["server.rsp_size"] <= 2**20)
            & (~df["timestamp"].isin(["2025-03-12 10:27:38", "2025-03-13 06:44:20"]))
            & (df["architecture_id"] <= 5)
            ]

    df.to_csv(f"{DATA_DIR}/filtered.csv", index=False)

    # Project to required columns
    x_axis = "Message Size [Byte]"
    y_axis_1 = "Median Latency [µs]"
    y_axis_2 = "p999 Latency"
    hue = "Communication Setting"

    data = DataFrame()
    data[x_axis] = df["server.rsp_size"]
    data[y_axis_1] = df["median"]
    data[y_axis_2] = df["p999"]
    data[hue] = df["architecture_id"].replace({id: setting for id, setting in zip(SETTING_IDs, SETTINGS)})

    data.sort_values([hue], inplace=True)

    # Set figure stile
    sns.set_style("ticks")
    sns.set_palette("deep")
    sns.set_context("notebook")

    f, (ax1, ax2) = plt.subplots(figsize=(6,2.5), ncols=2, sharey=True)
    sns.lineplot(data=data, y=y_axis_1, x=x_axis,
        hue=hue, style=hue, hue_order=SETTINGS, style_order=SETTINGS,
        markers=True,
        ax=ax1, legend=False)
    sns.lineplot(data=data, y=y_axis_2, x=x_axis,
        hue=hue, style=hue, hue_order=SETTINGS, style_order=SETTINGS,
        markers=True, ax=ax2)

    # Styling
    sns.move_legend(ax2, "lower center", frameon=False, bbox_to_anchor=(-0.1, 0.95), ncols=5, title=None,
                    columnspacing=0.8)

    for ax in (ax1, ax2):
        ax.set_xscale("log")
        ax.set_yscale("log")
        ax.set_xticks([2**x for x in range(6,21)],TICKS[6:21],rotation=90)
        ax.set_xlim((64, 2**20))
        ax.tick_params(axis='x', which='minor', bottom=False)
        ax.grid(axis="y")

    ax2.set_ylabel(y_axis_2, visible=True)

    plt.tight_layout(pad=0.5)
    plt.subplots_adjust(wspace=0.2)

    # Save
    plt.savefig(f"{IMG_DIR}/latency.pdf", dpi=300)
    plt.close()


def plot_verify():
    df = pd.read_csv(f"{DATA_DIR}/results.csv")

    # Filter to required results
    df = df[(df["client.msg_size"] == 8)
            & (df["instance_type"].isin(["c5.2xlarge", "c6i.2xlarge", "c6in.8xlarge"]))
            & (df["server.rsp_size"] >= 64)
            & (df["server.rsp_size"] <= 2**20)
            #& (df["timestamp"] != "2025-03-12 10:27:38")
            & (df["architecture_id"] == 2)]

    df.to_csv(f"{DATA_DIR}/filtered.csv")

    # Project to required columns
    x_axis = "Message Size [Byte]"
    y_axis_1 = "Median Latency [µs]"
    y_axis_2 = "p999 Latency"
    hue = "Communication Setting"
    col = "timestamp"

    df = pd.melt(df, id_vars=['server.rsp_size', 'timestamp'], value_vars=['min', 'q25', 'median', "q75", "max"], var_name='percentile', value_name='value')

    # Set figure stile
    sns.set_style("ticks")
    sns.set_palette("deep")
    sns.set_context("notebook")

    p = sns.relplot(data=df, y="value", x="server.rsp_size", hue='percentile', style='percentile', col=col, markers=True, kind="line")
    sns.move_legend(p, "lower center", frameon=False, bbox_to_anchor=(0.5, 0.95), ncols=5, title=None,
                    columnspacing=0.8)

    for ax in p.axes.flatten():
        ax.set_xscale("log")
        ax.set_yscale("log")
        ax.set_xticks([2**x for x in range(6,21)],TICKS[6:21],rotation=90)
        ax.set_xlim((64, 2**20))
        ax.tick_params(axis='x', which='minor', bottom=False)
        ax.grid(axis="y")

    plt.tight_layout()

    # Save
    plt.savefig(f"{IMG_DIR}/latency_insight.png", bbox_inches='tight', pad_inches=0.1, dpi=300)
    plt.close()


def main():
    plot_paper()


if __name__ == '__main__':
    main()
