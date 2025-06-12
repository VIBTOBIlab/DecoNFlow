#!/usr/bin/env python

import pandas as pd
import argparse
import os
import sys
import re

pd.options.mode.chained_assignment = None
version = "0.1"
copyright = "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


def printVersion():
    sys.stderr.write("\nconvert_atlas.py, version" + " %s\n" % version)
    sys.stderr.write("\n" + copyright + "\n")
    sys.exit(-1)


def usage():
    sys.stderr.write(
        """Usage: python3 convert_atlas.py  [options] -m <matrix> \n
        -m <matrix>                       Matrix to be merged (.csv file)
        -c <collapse_approach>            How to collapse the samples (def. mean)
        """
    )
    sys.exit(-1)


def parse_arguments():
    # Specify the flags and print them
    parser = argparse.ArgumentParser()
    parser.add_argument("-m", "--matrix", help="Matrix to be merged")
    parser.add_argument(
        "-c", "--collapse_approach", help="How to collapse the samples", default="mean"
    )
    parser.add_argument(
        "-v", "--version", help="Version of the tool", action="store_true"
    )
    # check for I/O errors
    args = parser.parse_args()
    if args.version:
        printVersion()
    if args.matrix == None:
        sys.stderr.write("Error! Must specify the matrix\n")
        usage()

    return args

def extract_entity(col_name):
    match = re.match(r'([a-zA-Z0-9]+)_(\d+)-V', col_name)
    if match:
        return match.group(1)
    return col_name

def generate_df(file_path,collapse_approach):

    df = pd.read_csv(file_path)

    entities = {}
    for col in df.columns:
        if '-' in col:  # Process only columns that have the entity naming pattern
            entity = extract_entity(col)  # Extract entity name
            if entity not in entities:
                entities[entity] = []
            entities[entity].append(col)

    # Create a new DataFrame with the first three columns (chr, start, end)
    result_df = df[['chr', 'start', 'end']].copy()

    # For each entity, compute the mean across the identified columns and add it as a new column
    for entity, columns in entities.items():
        if collapse_approach=="mean":
            result_df[entity] = df[columns].mean(axis=1)
        elif collapse_approach=="median":
            result_df[entity] = df[columns].median(axis=1)
        else: raise Exception("Error: a value different from mean or median has been specified!")
    return result_df

def generate_csv(result_df):
    # Create the new column by concatenating chr, start, and end
    result_df['DMR'] = result_df['chr'].astype(str) + ":" + result_df['start'].astype(str) + "-" + result_df['end'].astype(str)
    result_df = result_df.drop(columns=['chr','start','end'])
    # Move the 'region' column to the front of the DataFrame
    cols = ['DMR'] + [col for col in result_df.columns if col != 'DMR']
    result_df = result_df[cols]
    return result_df

def main():
    # Get the arguments and print them in the output file
    args = parse_arguments()
    processed_matrix = generate_df(args.matrix, args.collapse_approach)
    processed_matrix.to_csv("converted_atlas.tsv", sep = '\t', index = False)

    processed_matrix_withDMR_col = generate_csv(processed_matrix)
    processed_matrix_withDMR_col.to_csv("converted_atlas.csv", index = False)

if __name__ == "__main__":
    main()
