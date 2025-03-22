#!/usr/bin/env python

import argparse
from pathlib import Path
import pandas as pd
from pandas import DataFrame
import re
import seaborn as sns
import matplotlib.pyplot as plt

def parse_filename(filename: str):
    minus_positions = [m.start() for m in re.finditer('-', filename)]
    filename = filename[minus_positions[2]+1:]
    number_of_enclaves_total = int(filename[0])
    enclave_index = int(filename[3])
    timestamp = filename[5:-4]

    return (number_of_enclaves_total, enclave_index, timestamp)

def create_part_df(parsed_filename) -> DataFrame:
    df = pd.read_csv(parsed_filename[0])

    meta_df = DataFrame([parsed_filename[1:]], columns=["nr_enclaves", "eid", "timestamp"])

    return pd.merge(df, meta_df, how='cross')

def main():
    parser = argparse.ArgumentParser(prog='combine_multi', description='Combine the converted CSVs for Multi Enclave setting.')
    parser.add_argument('-p', '--path', required=False, help='Path to convert all files in')
    args = parser.parse_args()

    if args.path is not None:
        data_dir = Path(args.path)
    else:
        data_dir = Path('./data/multi')

    paths = list(data_dir.glob('multi-enclave-c6i.4xlarge*.csv'))
    combined_path = data_dir / "combined.csv"
    if len(paths) == 0:
        print(f"No partial files found in {data_dir}. Using combined.csv")
        full_df = pd.read_csv(combined_path)
    else:
        parsed_filenames = [(path, ) + parse_filename(path.name) for path in paths]

        part_dfs = [create_part_df(parsed_filename) for parsed_filename in parsed_filenames]

        full_df = pd.concat(part_dfs, axis=0, ignore_index=True)

        full_df.drop(["cores", "message_size", "instance_type", "threads"], axis=1, inplace=True)

        multiplier = full_df["unit"].map(pd.Series({"Gbits/sec": 1.0, "Mbits/sec": 1.0/1000.0, "kbits/sec": 1.0/1_000_000.0})).infer_objects()
        full_df["throughput"] = full_df["throughput"] * multiplier
        full_df = full_df.drop(["unit"], axis=1)

        full_df.to_csv(combined_path, index=False)

    aggregated = full_df.groupby(["timestamp", "direction"]).agg({"eid": "sum", "nr_enclaves": "min", "throughput": "sum"})
    aggregated = aggregated.reset_index()
    aggregated = aggregated.drop(["timestamp", "eid"], axis=1).sort_values(["direction", "nr_enclaves"])

    x_axis = "Enclave Count"
    y_axis = "Aggregated\nThroughput [Gbit/s]"
    hue = "Direction"

    aggregated.columns = [hue, x_axis, y_axis]
    aggregated[hue] = aggregated[hue].replace({"forward": "Into Enclave(s)", "backward": "Out of Enclave(s)"})

    sns.set_style("ticks")
    sns.set_palette("deep")
    sns.set_context("notebook")

    f = plt.figure(figsize=(6, 2.5))
    p = sns.barplot(data=aggregated, x=x_axis, y=y_axis, hue=hue, hue_order=["Into Enclave(s)", "Out of Enclave(s)"])
    sns.move_legend(p, "lower center", frameon=False, bbox_to_anchor=(0.5, 0.95), ncols=2, title=None)
    plt.grid(axis="y")

    plt.tight_layout(pad=0.5)

    plt.savefig("img/multi.pdf", dpi=600)


if __name__ == '__main__':
    main()
