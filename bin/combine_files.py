#!/usr/bin/env python

import pandas as pd
import sys
import argparse
import ast

version = "0.1"
copyright = "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


def printVersion():
    sys.stderr.write("\ncombine_files.py, version" + " %s\n" % version)
    sys.stderr.write("\n" + copyright + "\n")
    sys.exit(-1)


def usage():
    sys.stderr.write(
        """
        Usage: python3 combine_files.py <file_paths> -o <output_file> \n
        """
    )
    sys.exit(-1)


def parse_arguments():
    # Specify the flags and print them
    parser = argparse.ArgumentParser()
    parser.add_argument('file_paths', nargs='*', help='A list of file paths to process')
    parser.add_argument('-o','--outfile', type = str, help='Output file')
    parser.add_argument(
        "-v", "--version", help="Version of the tool", action="store_true"
    )

    args = parser.parse_args()
    if args.version:
        printVersion()
    if args.outfile == None:
        print("Specify the output file")
        usage()
    return args


def merge_files(paths):
    df = pd.DataFrame()
    for path in paths:
        tool = path.split(":")[0]
        filePath = path.split(":")[1]
        if filePath.endswith(".txt"):
            deconvFile = pd.read_csv(filePath,sep="\t")
        else: deconvFile = pd.read_csv(filePath,sep=",")
        deconvFile.columns.values[0] = "sample"
        deconvFile[['tool']] = tool
        df = pd.concat([df,deconvFile], axis = 0)
    return df.reset_index(drop = True)


def main():
    # Get the arguments and print them in the output file
    args = parse_arguments()
    # Read from standard input
    file_paths = args.file_paths[0].strip()[1:-1].split(',')
    res_df = merge_files(file_paths)
    res_df.to_csv(args.outfile+".csv", index = False)


if __name__ == "__main__":
    main()
