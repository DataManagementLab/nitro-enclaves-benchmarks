#!/usr/bin/env python

import matplotlib.pyplot as plt
import pandas as pd
from pandas import DataFrame
import seaborn as sns
from pathlib import Path


def prepare_data(df):
    multiplier = df["unit"].map(pd.Series({"Gbits/sec": 1.0, "Mbits/sec": 1.0/1000.0, "kbits/sec": 1.0/1_000_000.0})).infer_objects()
    df["throughput"] = df["throughput"] * multiplier
    df = df.drop(["unit"], axis=1)
    return df


def plot_comparison_facets(instance_types: list[str]):
    df: DataFrame = pd.read_csv('data/single-enclave/all.csv')

    df = df.loc[df["instance_type"].isin(instance_types)]
    df = df[df["threads"].isin([1,2,4,5,6,7,8,16])]

    df = prepare_data(df)

    x_axis = "Threads"
    y_axis = "Throughput [Gbit/s]"
    col = "Direction"
    hue = "Instance Type"

    df[x_axis] = df["threads"]
    df[y_axis] = df["throughput"]
    #df[col] = df["direction"].replace({"forward": "Into Enclave", "backward": "Out of Enclave"})
    df[hue] = df["instance_type"]

    f, (ax1, ax2) = plt.subplots(figsize=(6,2.5), ncols=2, sharey=True)
    sns.boxplot(data=df.loc[df["direction"] == "forward"], x=x_axis, y=y_axis, hue=hue,
                hue_order=instance_types, ax=ax1, legend=False)

    sns.boxplot(data=df.loc[df["direction"] == "backward"], x=x_axis, y=y_axis, hue=hue,
                hue_order=instance_types, ax=ax2)

    sns.move_legend(ax2, "lower center", frameon=False, bbox_to_anchor=(-0.15, 1.1), ncols=len(instance_types), title=None,
                    columnspacing=0.8, fontsize=10)

    #plt.xscale("log")
    #plt.xticks([1,2,4,8,16,32],[1,2,4,8,16,32])
    #plt.minorticks_off()
    ax1.grid(axis="y")
    ax1.title.set_text("Into Enclave")
    ax2.grid(axis="y")
    ax2.title.set_text("Out of Enclave")

    plt.tight_layout(pad=0.5)
    plt.subplots_adjust(wspace=0.1, right=0.985, top=0.8)

    plt.savefig(f"img/comparison-{'-'.join(instance_types)}.pdf", dpi=600)
    plt.close()


def plot_generation_cpu_arch():
    df = pd.read_csv('data/single-enclave/all.csv')
    df = df[df["threads"] == 4]
    df = df[df["direction"] == "forward"]
    df = prepare_data(df)

    y_axis = "Throughput [Gbit/s]"
    x_axis_1 = "CPU Architecture"
    x_axis_2 = "Instance Generation"

    df[y_axis] = df["throughput"]

    cpu_instance_types = ["c6i.2xlarge", "c6a.2xlarge", "c6g.2xlarge"]
    generation_instance_types = ["c5.2xlarge", "c6i.2xlarge", "c7i.2xlarge"]

    cpu_types_df = df.loc[df["instance_type"].isin(cpu_instance_types)]
    generation_df = df.loc[df["instance_type"].isin(generation_instance_types)]

    f, (ax1, ax2) = plt.subplots(figsize=(6,2.5), ncols=2, sharey=True)

    sns.boxplot(data=cpu_types_df, y=y_axis, x="instance_type", order=cpu_instance_types, ax=ax1)
    sns.boxplot(data=generation_df, y=y_axis, x="instance_type", order=generation_instance_types, ax=ax2)

    ax1.set_xticks([0,1,2], ["Intel", "AMD", "Graviton"])
    ax1.set_xlabel(x_axis_1)
    ax2.set_xticks([0,1,2], ["c5", "c6i", "c7i"])
    ax2.set_xlabel(x_axis_2)

    ax1.grid(axis="y")
    ax2.grid(axis="y")

    plt.tight_layout(pad=0.5)

    plt.savefig("img/generation_arch.pdf", dpi=600)


def plot_message_size():
    data = pd.read_csv("data/message-size/all.csv")
    data = prepare_data(data)

    baseline = pd.read_csv("data/cross_instance/all.csv")
    baseline = prepare_data(baseline)

    data = data.loc[~data["message_size"].isin(["2M", "4M"]) & (data["threads"] == 4) & (data["instance_type"] == "c6i.2xlarge")]
    baseline = baseline.loc[baseline["threads"] == 8]

    # remove outliers
    data = data[~(data["message_size"].isin(["512K", "1M"]) & (data["throughput"] < 1))]

    x_axis = "Message Size [Byte]"
    y_axis = "Throughput [Gbit/s]"
    setting = "Protocol"

    combined = pd.concat([
        data.loc[:, ["message_size", "throughput"]],
        baseline.loc[:, ["message_size", "throughput"]],
    ], axis=0, ignore_index=True)
    combined.columns = [x_axis, y_axis]
    combined[setting] = ["VSOCK"] * data.shape[0] + ["TCP/IP"] * baseline.shape[0]

    f = plt.figure(figsize=(6, 2.5))
    p = sns.lineplot(data=combined, x=x_axis, y=y_axis, hue=setting, style=setting, markers=True)
    sns.move_legend(p, "lower center", frameon=False, bbox_to_anchor=(0.5, 0.95), ncols=2, title=None)

    plt.xticks(rotation=90)
    p.yaxis.set_label_coords(-0.08,0.45)
    plt.grid(axis="y")

    plt.tight_layout(pad=0.5)
    plt.savefig("img/message_size.pdf", dpi=600)
    plt.close()


def main():
    sns.set_style("ticks")
    sns.set_palette("deep")
    sns.set_context("notebook")

    plot_comparison_facets(["c6i.2xlarge", "c6i.4xlarge", "c6i.8xlarge", "c6in.8xlarge"])

    plot_generation_cpu_arch()

    plot_message_size()


if __name__ == '__main__':
    main()
