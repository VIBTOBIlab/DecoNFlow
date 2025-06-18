#!/usr/bin/env python

import pandas as pd
import argparse
import os
import sys

pd.options.mode.chained_assignment = None
version = "0.1"
copyright = "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


def printVersion():
    sys.stderr.write("\nmerge_tables.py, version" + " %s\n" % version)
    sys.stderr.write("\n" + copyright + "\n")
    sys.exit(-1)


def usage():
    sys.stderr.write(
        """Usage: python3 merge_tables.py  [options] -i <reference> -t <testing> \n
        -i <reference>          .csv reference file with the structure required by CelFiE
        -t <testing>            .csv testing file with the structure required by CelFiE
        """
    )
    sys.exit(-1)


def parse_arguments():
    # Specify the flags and print them
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--reference", help="Reference sample sheet")
    parser.add_argument(
        "-t", "--testing", help="Regions to be used to cluster the CpGs"
    )
    parser.add_argument(
        "-v", "--version", help="Version of the tool", action="store_true"
    )
    # check for I/O errors
    args = parser.parse_args()
    if args.version:
        printVersion()
    if args.reference == None:
        sys.stderr.write("Error! Must specify the input file\n")
        usage()
    if args.testing == None:
        sys.stderr.write("Error! Must specify the regions file\n")
        usage()

    return args


def merge_files(ref, test):
    ref_df = pd.read_csv(ref, index_col = 0)
    test_df = pd.read_csv(test, index_col = 0)
    ref_df.index = ref_df.chr.astype(str)+':'+ref_df.start.astype(str)+'-'+ref_df.end.astype(str)
    test_df.index = test_df.chr.astype(str)+':'+test_df.start.astype(str)+'-'+test_df.end.astype(str)
    ref_df = order_cols(ref_df.copy())
    test_df = order_cols(test_df.copy())
    merged_files = pd.concat([test_df, ref_df], axis = 1, join = 'inner')
    return merged_files


def order_cols(df):
    # Extract the prefix for each column
    prefixes = []
    for col in df.columns:
        parts = col.split('_')
        if len(parts) > 1 and parts[-1] in {'meth', 'depth'}:
            prefix = '_'.join(parts[:-1])
            if prefix not in prefixes:
                prefixes.append(prefix)

    # Create the new column order
    new_order = []
    sorted_prefixes = sorted(prefixes)

    for prefix in sorted_prefixes:
        new_order.append(f"{prefix}_meth")
        new_order.append(f"{prefix}_depth")

    # Include the 'chr', 'start', 'end' columns at the beginning
    static_columns = ['chr', 'start', 'end']
    new_order = static_columns + new_order
    # Reorder the DataFrame
    df = df[new_order]
    return df


def main():
    # Get the arguments and print them in the output file
    args = parse_arguments()
    processed_matrix = merge_files(args.reference, args.testing)
    processed_matrix.to_csv("celfie_matrix.txt", sep = '\t', index = False)

if __name__ == "__main__":
    main()
