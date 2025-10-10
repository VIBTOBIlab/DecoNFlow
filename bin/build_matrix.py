#!/usr/bin/env python

import pandas as pd
import argparse
import numpy as np
import os
import sys
import re

pd.options.mode.chained_assignment = None
version = "0.1"
copyright = "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


def printVersion():
    sys.stderr.write("\npreprocessing.py, version" + " %s\n" % version)
    sys.stderr.write("\n" + copyright + "\n")
    sys.exit(-1)


def usage():
    sys.stderr.write(
        """Usage: python3 preprocessing.py  [options] --file_paths \n
        --file_paths              List of .csv files representing the samples to deconvolve

        """
    )
    sys.exit(-1)


def parse_arguments():
    # Specify the flags and print them
    parser = argparse.ArgumentParser()
    parser.add_argument("--file_paths", help="File containing the paths of the samples")
    parser.add_argument("--outfile", help="File containing the paths of the samples")
    parser.add_argument("--how", help="Type of merge to be performed. It can be outer or inner (def.)")
    parser.add_argument("--celfie_atlas", action="store_true", help="If specified, it performs the merging for CelFiE atlas.")
    parser.add_argument(
        "-v", "--version", help="Version of the tool", action="store_true"
    )

    # check for I/O errors
    args = parser.parse_args()
    if args.version:
        printVersion()
    if args.file_paths == None:
        sys.stderr.write("Error! Must specify the input file\n")
        usage()
    return args


def merge_files(paths, how, celfie_atlas, outfile):
    """It merges the files in a count matrix using the in common regions."""
    df = pd.read_csv(paths[0], index_col = 0, low_memory=False)

    df['chr'] = df['chr'].astype(str)
    df['start'] = df['start'].astype(int)
    df['end'] = df['end'].astype(int)

    for file in paths[1:]:
        new_df = pd.read_csv(file, index_col = 0, low_memory=False)
        new_df['chr'] = new_df['chr'].astype(str)
        new_df['start'] = new_df['start'].astype(int)
        new_df['end'] = new_df['end'].astype(int)
        if how == 'outer':
            df = pd.merge(df,new_df,on=['chr','start','end'], how = 'outer')
        elif how == 'outer_fillna':
            df = pd.merge(df,new_df,on=['chr','start','end'], how = 'outer').fillna(0)
        else: df = pd.merge(df,new_df,on=['chr','start','end'], how = 'inner')

    # Separate first three columns (they won't be sorted)
    first_three_cols = df[['chr', 'start', 'end']]

    # Get the remaining columns
    remaining_cols = df[df.columns.difference(['chr', 'start', 'end'])]

    # Sort the remaining columns using the custom key
    sorted_cols = sorted(remaining_cols, key=sort_key)

    # Concatenate the two parts
    df_sorted = pd.concat([first_three_cols, df[sorted_cols]], axis=1)
    df_sorted = df_sorted.sort_values(by=['chr','start','end']).reset_index(drop=True)

    # If celfie atlas is specified, reformat the matrix accordingly and save it
    if celfie_atlas == True:
        df_celfie = celfie_atlas_format(df_sorted)
        df_celfie.to_csv("final_"+outfile)
        return df_celfie

    # Otherwise, just save the sorted, concatanated matrix
    df_sorted.to_csv(outfile)
    return df_sorted


def sort_key(x):
    # Check for the presence of '_meth' or '_depth'
    has_meth = '_meth' in x
    has_depth = '_depth' in x

    # Determine the base name; if there is no underscore, use the full name as base
    base_name = x.rsplit('_', 1)[0] if '_' in x else x

    # Return a tuple for sorting:
    # 1. base name (for grouping)
    # 2. priority for '_meth' columns (True = comes first)
    # 3. priority for '_depth' columns (True = comes after '_meth')
    # 4. original column name (for tiebreaking)
    return (base_name, not has_meth, has_depth, x)


def celfie_atlas_format(df_celfie):
    # Get unique entity prefixes
    for col in df_celfie.columns[3:]:
        new_col = col.split("_")[0]+"_"+col.split("_")[-1]
        df_celfie = df_celfie.rename(columns = {col:new_col})
    # Group the DataFrame by entities
    grouped = df_celfie.groupby(axis=1, level=0, sort=False).sum()
    return grouped


def main():
    args = parse_arguments()

    file_paths = args.file_paths.split(" ")

    merge_files(file_paths,
                args.how,
                args.celfie_atlas,
                args.outfile)

    #res_df.to_csv(args.outfile)


if __name__ == "__main__":
    main()
