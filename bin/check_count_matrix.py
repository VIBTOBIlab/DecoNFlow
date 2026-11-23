#!/usr/bin/env python
"""Validate a user-provided count reference matrix and convert it to CSV.

The count matrices of CelFiE (``--celfie_ref_matrix``) and MetDecode
(``--metdecode_ref_matrix``) must be tab-separated files whose first three
columns are ``chr``, ``start`` and ``end``, followed by a ``<cell type>_meth``
and a ``<cell type>_depth`` column per cell type (at least two, uniquely named)
holding the methylated and total read counts of each region, without missing
values.

If the file is valid it is written to ``count_matrix.csv``, the CelFiE-like
format used by the pipeline (an index column followed by the same columns).
Otherwise the script exits with an error message.

Author: Edoardo Giuili (edoardo.giuili@ugent.be)
"""

import argparse
import sys

import pandas as pd

__version__ = "0.1"

COORDINATES = ["chr", "start", "end"]
COUNT_SUFFIXES = ("meth", "depth")
OUTFILE = "count_matrix.csv"


def parse_arguments():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser(
        description="Check a count reference matrix (TSV) and convert it to CSV."
    )
    parser.add_argument("tsv_file", help="Path to the count reference matrix (TSV).")
    parser.add_argument(
        "-v", "--version", action="version", version=f"%(prog)s {__version__}"
    )
    return parser.parse_args()


def read_matrix(path):
    """Read the count matrix, making sure it is tab-separated."""
    with open(path) as handle:
        header = handle.readline()
    if "\t" not in header:
        raise ValueError("File does not appear to be tab-separated.")

    # Check the raw header: pandas would silently rename duplicates ('a', 'a.1')
    columns = header.rstrip("\r\n").split("\t")
    if len(set(columns)) != len(columns):
        raise ValueError("Column names are not unique.")

    return pd.read_csv(path, sep="\t")


def cell_types(columns):
    """Return the cell types of the '<cell type>_meth' / '<cell type>_depth' pairs.

    The count columns must come in pairs, the '_meth' column of each cell type
    directly followed by its '_depth' column.
    """
    count_columns = list(columns[len(COORDINATES) :])
    if len(count_columns) % 2:
        raise ValueError(
            "Each cell type needs a '_meth' and a '_depth' column, "
            "found an odd number of count columns."
        )

    names = []
    for meth, depth in zip(count_columns[::2], count_columns[1::2]):
        name = meth[: -len("_meth")]
        if not meth.endswith("_meth") or not name or depth != f"{name}_depth":
            raise ValueError(
                f"Expected a '<cell type>_meth' column followed by its "
                f"'<cell type>_depth' column, found '{meth}' and '{depth}'."
            )
        names.append(name)
    return names


def validate_matrix(df):
    """Raise a ValueError if the count matrix is not in the expected format."""
    if list(df.columns[: len(COORDINATES)]) != COORDINATES:
        raise ValueError("First three columns are not named 'chr', 'start', 'end'.")
    if len(cell_types(df.columns)) < 2:
        raise ValueError("Count matrix does not have at least two cell types.")
    if df.empty:
        raise ValueError("Count matrix has no regions.")
    if df.isnull().values.any():
        raise ValueError("The file contains missing values (NaNs).")

    counts = df.drop(columns=COORDINATES)
    non_numeric = [
        col for col in counts.columns if not pd.api.types.is_numeric_dtype(counts[col])
    ]
    if non_numeric:
        raise ValueError(f"Non-numeric counts in columns: {', '.join(non_numeric)}.")
    if (counts < 0).values.any():
        raise ValueError("The file contains negative counts.")

    meth = counts.iloc[:, ::2].to_numpy()
    depth = counts.iloc[:, 1::2].to_numpy()
    if (meth > depth).any():
        raise ValueError(
            "Some methylated counts ('_meth') are larger than the total counts ('_depth')."
        )


def main():
    args = parse_arguments()

    try:
        matrix = read_matrix(args.tsv_file)
        validate_matrix(matrix)
    except (OSError, ValueError, pd.errors.ParserError) as error:
        sys.exit(f"Error: {error}")

    matrix.to_csv(OUTFILE)
    print(f"File format is correct. Data has been written to {OUTFILE}")


if __name__ == "__main__":
    main()
