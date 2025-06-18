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
    parser.add_argument('--results', nargs='*', help='A list of results files to process')
    parser.add_argument('--tool_names', nargs='*', help='A list of tools names corresponding to the results to process')
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


def merge_files(paths,tools):
    df = pd.DataFrame()
    for i in range(len(paths)):

        tool = tools[i]
        path = paths[i]

        if path.endswith(".txt"):
            deconvFile = pd.read_csv(path,sep="\t")
        else: deconvFile = pd.read_csv(path,sep=",")

        deconvFile.columns.values[0] = "sample"
        deconvFile[['tool']] = tool
        df = pd.concat([df,deconvFile], axis = 0)

    return df.reset_index(drop = True)


def main():
    # Get the arguments and print them in the output file
    args = parse_arguments()
    # Read from standard input
    file_paths = args.results
    tool_names = args.tool_names
    res_df = merge_files(file_paths,tool_names)
    res_df.to_csv(args.outfile+".csv", index = False)


if __name__ == "__main__":
    main()
