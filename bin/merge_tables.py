#!/usr/bin/env python
"""Build the input table for CelFiE from the bulk samples and the reference atlas.

Both inputs are CelFiE-like CSV files with the region coordinates (``chr``,
``start``, ``end``) followed by a ``<name>_meth`` and a ``<name>_depth`` column
per sample (bulk) or entity (atlas). The two tables are joined on the regions
they share and written side by side, bulk samples first, to the tab-separated
``celfie_matrix.txt``.

Author: Edoardo Giuili (edoardo.giuili@ugent.be)
"""

import argparse

import pandas as pd

__version__ = "0.2"

COORDINATES = ["chr", "start", "end"]
COUNT_SUFFIXES = ("meth", "depth")
OUTFILE = "celfie_matrix.txt"


def parse_arguments():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser(
        description="Join the bulk samples and the reference atlas for CelFiE."
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


def read_celfie_table(path):
    """Read a CelFiE-like table, indexed by region (chr:start-end)."""
    df = pd.read_csv(path, index_col=0)
    df.index = (
        df["chr"].astype(str)
        + ":"
        + df["start"].astype(str)
        + "-"
        + df["end"].astype(str)
    )
    return df


def order_columns(df):
    """Keep the coordinates followed by the '_meth' / '_depth' pair of each name.

    Names are sorted alphabetically; columns that do not end in '_meth' or
    '_depth' are dropped.
    """
    names = {
        col.rsplit("_", 1)[0]
        for col in df.columns
        if "_" in col and col.rsplit("_", 1)[1] in COUNT_SUFFIXES
    }
    count_columns = [
        f"{name}_{suffix}" for name in sorted(names) for suffix in COUNT_SUFFIXES
    ]
    return df[COORDINATES + count_columns]


def main():
    args = parse_arguments()

    reference = order_columns(read_celfie_table(args.reference))
    samples = order_columns(read_celfie_table(args.testing))

    # Keep the regions shared by both tables, bulk samples first
    merged = pd.concat([samples, reference], axis=1, join="inner")
    merged.to_csv(OUTFILE, sep="\t", index=False)


if __name__ == "__main__":
    main()
