#!/usr/bin/env python
"""Validate a user-provided reference matrix and convert it to CSV.

The reference matrix (``--ref_matrix``) must be a tab-separated file whose
first three columns are ``chr``, ``start`` and ``end``, followed by one column
per cell type (at least two, uniquely named) and without missing values.

If the file is valid it is written to ``reference.csv`` with the coordinates
collapsed into a single ``DMR`` column (``chr:start-end``). Otherwise the
script exits with an error message.

Author: Edoardo Giuili (edoardo.giuili@ugent.be)
"""

import argparse
import sys

import pandas as pd

__version__ = "0.2"

COORDINATES = ["chr", "start", "end"]
OUTFILE = "reference.csv"


def parse_arguments():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser(
        description="Check a reference matrix (TSV) and convert it to CSV."
    )
    parser.add_argument("tsv_file", help="Path to the reference matrix (TSV).")
    parser.add_argument(
        "-v", "--version", action="version", version=f"%(prog)s {__version__}"
    )
    return parser.parse_args()


def read_reference(path):
    """Read the reference matrix, making sure it is tab-separated."""
    if not path.endswith((".tsv", ".bed")):
        print("Warning: File does not have a .tsv or .bed extension.", file=sys.stderr)

    with open(path) as handle:
        header = handle.readline()
    if "\t" not in header:
        raise ValueError("File does not appear to be tab-separated.")

    # Check the raw header: pandas would silently rename duplicates ('a', 'a.1')
    cell_types = header.rstrip("\r\n").split("\t")[len(COORDINATES) :]
    if len(set(cell_types)) != len(cell_types):
        raise ValueError("Cell type columns are not uniquely named.")

    return pd.read_csv(path, sep="\t")


def validate_reference(df):
    """Raise a ValueError if the reference matrix is not in the expected format."""
    if df.isnull().values.any():
        raise ValueError("The file contains missing values (NaNs).")
    if list(df.columns[: len(COORDINATES)]) != COORDINATES:
        raise ValueError("First three columns are not named 'chr', 'start', 'end'.")
    if len(df.columns) - len(COORDINATES) < 2:
        raise ValueError("Reference matrix does not have at least two cell types.")


def to_dmr_format(df):
    """Replace the coordinate columns with a single 'DMR' column (chr:start-end)."""
    dmr = (
        df["chr"].astype(str)
        + ":"
        + df["start"].astype(str)
        + "-"
        + df["end"].astype(str)
    )
    return pd.concat([dmr.rename("DMR"), df.drop(columns=COORDINATES)], axis=1)


def main():
    args = parse_arguments()

    try:
        reference = read_reference(args.tsv_file)
        validate_reference(reference)
    except (OSError, ValueError, pd.errors.ParserError) as error:
        sys.exit(f"Error: {error}")

    to_dmr_format(reference).to_csv(OUTFILE, index=False)
    print(f"File format is correct. Data has been written to {OUTFILE}")


if __name__ == "__main__":
    main()
