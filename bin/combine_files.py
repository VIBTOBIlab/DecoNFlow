#!/usr/bin/env python
"""Combine the cell-type proportions estimated by each deconvolution tool.

Each result file has one row per sample, the sample name in the first column
and one column per cell type. The files are stacked into a single table with
the first column renamed to ``sample`` and an extra ``tool`` column saying
which tool produced each row.

Author: Edoardo Giuili (edoardo.giuili@ugent.be)
"""

import argparse

import pandas as pd

__version__ = "0.2"


def parse_arguments():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser(
        description="Combine the results of several deconvolution tools in one table."
    )
    parser.add_argument(
        "--results",
        nargs="+",
        required=True,
        help="Result files to combine (.txt files are read as TSV, others as CSV).",
    )
    parser.add_argument(
        "--tool_names",
        nargs="+",
        required=True,
        help="Name of the tool that produced each result file, in the same order.",
    )
    parser.add_argument(
        "-o",
        "--outfile",
        required=True,
        help="Output file name, without the .csv extension.",
    )
    parser.add_argument(
        "-v", "--version", action="version", version=f"%(prog)s {__version__}"
    )

    args = parser.parse_args()
    if len(args.results) != len(args.tool_names):
        parser.error("--results and --tool_names must have the same number of values.")
    return args


def read_result(path, tool):
    """Read one result file and label its rows with the tool name."""
    sep = "\t" if path.endswith(".txt") else ","
    result = pd.read_csv(path, sep=sep)
    result = result.rename(columns={result.columns[0]: "sample"})
    result["tool"] = tool
    return result


def combine_results(paths, tools):
    """Stack the results of all tools into a single table."""
    results = [read_result(path, tool) for path, tool in zip(paths, tools)]
    return pd.concat(results, axis=0, ignore_index=True)


def main():
    args = parse_arguments()
    combined = combine_results(args.results, args.tool_names)
    combined.to_csv(f"{args.outfile}.csv", index=False)


if __name__ == "__main__":
    main()
