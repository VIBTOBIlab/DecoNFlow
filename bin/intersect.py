#!/usr/bin/env python

import pandas as pd
import argparse
import os
import sys

pd.options.mode.chained_assignment = None
version = "0.1"
copyright = "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


def printVersion():
    sys.stderr.write("\nintersect.py, version" + " %s\n" % version)
    sys.stderr.write("\n" + copyright + "\n")
    sys.exit(-1)


def usage():
    sys.stderr.write(
        """Usage: python3 intersect.py  [options] -i <reference> -t <testing> \n
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


def intersect(ref, test):
    atlas = pd.read_csv(ref, index_col = 0)
    samples = pd.read_csv(test, index_col = 0)
    common_regions = pd.merge(atlas[['chr', 'start', 'end']], samples[['chr', 'start', 'end']], on=['chr', 'start', 'end'],how='inner')
    # Subset df1 and df2 based on the common regions
    subset_df1 = pd.merge(common_regions,atlas, on=['chr', 'start', 'end'])
    subset_df2 = pd.merge(common_regions,samples, on=['chr', 'start', 'end'])
    return subset_df1,subset_df2

def main():
    # Get the arguments and print them in the output file
    args = parse_arguments()
    atlas, samples = intersect(args.reference, args.testing)
    atlas.to_csv("atlas.csv")
    samples.to_csv("samples.csv")

if __name__ == "__main__":
    main()
