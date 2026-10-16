#!/usr/bin/env python
"""Restrict the reference atlas and the bulk samples to their shared regions.

Both inputs are CelFiE-like CSV files with the region coordinates (``chr``,
``start``, ``end``) followed by the ``_meth`` / ``_depth`` count columns. Only
the regions present in both files are kept, and the results are written to
``atlas.csv`` and ``samples.csv`` (used by MetDecode).

Author: Edoardo Giuili (edoardo.giuili@ugent.be)
"""

import argparse

import pandas as pd

__version__ = "0.2"

COORDINATES = ["chr", "start", "end"]


def parse_arguments():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser(
        description="Keep the regions shared by the atlas and the bulk samples."
    )
    parser.add_argument(
        "-i",
        "--reference",
        required=True,
        help="Reference atlas (CSV) in the CelFiE format.",
    )
    parser.add_argument(
        "-t",
        "--testing",
        required=True,
        help="Bulk samples (CSV) in the CelFiE format.",
    )
    parser.add_argument(
        "-v", "--version", action="version", version=f"%(prog)s {__version__}"
    )
    return parser.parse_args()


def intersect(atlas, samples):
    """Return the atlas and the samples restricted to their common regions."""
    common_regions = atlas[COORDINATES].merge(samples[COORDINATES], on=COORDINATES)
    return (
        common_regions.merge(atlas, on=COORDINATES),
        common_regions.merge(samples, on=COORDINATES),
    )


def main():
    args = parse_arguments()

    atlas = pd.read_csv(args.reference, index_col=0)
    samples = pd.read_csv(args.testing, index_col=0)

    atlas, samples = intersect(atlas, samples)
    atlas.to_csv("atlas.csv")
    samples.to_csv("samples.csv")


if __name__ == "__main__":
    main()
