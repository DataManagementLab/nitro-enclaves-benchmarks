#!/usr/bin/env python

import argparse
from pathlib import Path
from pprint import pprint
import pandas as pd
from typing import List, Tuple, Union


def determine_block_indexes(lines: List[str]) -> List[Tuple[int, int]]:
    starts = []
    ends = []
    for i, line in enumerate(lines):
        if line.startswith('[C -> S]') or line.startswith('[S -> C]'):
            starts.append(i)
        if line == "iperf Done.\n":
            ends.append(i)
    return zip(starts, ends)


def determine_block_settings(block: List[str]) -> Tuple[str, int, str]:
    direction = "forward" if block[0].startswith('[C -> S]') else "backward"
    threads = int(block[0][9:].split()[0])

    split = block[0].split()

    if len(split) == 8:
        message_size = split[7]
    else:
        message_size = ""

    return direction, threads, message_size


def trim_block(block: List[str]) -> List[str]:
    start_index = 0
    for i, line in enumerate(block):
        if line.count("ID") == 1:
            start_index = i
            break
    return block[start_index:-2]


def extract_summary(block: List[str]) -> Union[str, None]:
    sender_lines = [line for line in block if line.count("sender") == 1]
    return sender_lines[-1] if sender_lines else None


def extract_throughput(line: str) -> Tuple[float, str]:
    values = line[5:].split()
    return float(values[4]), values[5]


def convert_file(path: Path) -> pd.DataFrame:
    with open(path, 'r') as f:
        lines = f.readlines()

    filename = path.name

    instance_type = filename.split("-")[2]
    cores = filename.split("-")[3]

    block_indexes = determine_block_indexes(lines)
    blocks = [lines[start:end+1] for start, end in block_indexes]
    block_settings = [determine_block_settings(block) for block in blocks]
    blocks = [trim_block(block) for block in blocks]

    sender_summaries = [extract_summary(block) for block in blocks]
    throughput = [extract_throughput(line) for line in sender_summaries if line is not None]
    if not throughput:
        return pd.DataFrame()

    table = [(instance_type, cores) + x + y for x, y in zip(block_settings, throughput)]

    df = pd.DataFrame(data=table, columns=["instance_type", "cores", "direction", "threads", "message_size", "throughput",
                                           "unit"])
    return df
    #df.to_csv(filename[:-4] + ".csv", index=False)


def main():
    parser = argparse.ArgumentParser(prog='convert_to_csv', description='Convert the outputs of iperf3 to a csv file.')
    parser.add_argument('-f', '--filename', required=False, help='The input file')
    parser.add_argument('-p', '--path', required=False, help='Path to convert all files in')
    parser.add_argument('-c', '--combine', required=False, help='Combine CSVs into all.csv. Only used if --path is used', action='store_true')
    args = parser.parse_args()

    if args.filename is not None:
        df = convert_file(Path(args.filename))
        df.to_csv(args.filename[:-4] + ".csv", index=False)
    else:
        if args.path is not None:
            data_dir = Path(args.path)
        else:
            data_dir = Path('./data')
        paths = list(data_dir.glob('*.txt'))
        print(f"Converting files in {data_dir}")
        print(f"Converting files {list(paths)}")
        if args.combine:
            print("Combining files to one csv.")
            df = pd.concat([convert_file(path) for path in paths])
            df.sort_values(by=['instance_type', 'cores', 'direction', 'threads'], inplace=True)
            df.to_csv(data_dir / "all.csv", index=False)
        else:
            for path in paths:
                df = convert_file(path)
                if df.empty:
                    print(f"Skipping {path} as it is empty.")
                    continue
                df.sort_values(by=['instance_type', 'cores', 'direction', 'threads'], inplace=True)
                df.to_csv(data_dir / f"{path.stem}.csv", index=False)


if __name__ == '__main__':
    main()
