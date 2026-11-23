#!/usr/bin/env python
"""Merge per-sample region tables into a single matrix.

Each input CSV holds one sample (or one group of samples) with the genomic
coordinates of the regions (``chr``, ``start``, ``end``) followed by one or
more value columns (beta values, or ``<entity>_..._meth`` / ``_depth`` counts
for CelFiE-like inputs). The files are joined on the coordinates, the value
columns are put in a stable order and the rows are sorted by position.

With ``--celfie_atlas`` the reference samples are additionally collapsed per
entity (cell type) by summing their methylated and total counts, which is the
atlas format expected by CelFiE and MetDecode.

Author: Edoardo Giuili (edoardo.giuili@ugent.be)
"""

import argparse

import pandas as pd

__version__ = "0.2"

COORDINATES = ["chr", "start", "end"]
MERGE_MODES = ["inner", "outer", "outer_fillna"]


def parse_arguments():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser(
        description="Merge per-sample region tables into a single matrix."
    )
    parser.add_argument(
        "--file_paths",
        required=True,
        help="Space-separated list of the CSV files to merge.",
    )
    parser.add_argument(
        "--outfile",
        required=True,
        help="Name of the output CSV file.",
    )
    parser.add_argument(
        "--how",
        choices=MERGE_MODES,
        default="inner",
        help=(
            "How to join the files on the region coordinates: 'inner' keeps the "
            "regions shared by all files, 'outer' keeps all regions (missing "
            "values as NaN) and 'outer_fillna' keeps all regions with missing "
            "values set to 0 (default: inner)."
        ),
    )
    parser.add_argument(
        "--celfie_atlas",
        action="store_true",
        help=(
            "Collapse the samples per entity into a CelFiE atlas and save it "
            "as 'final_<outfile>'."
        ),
    )
    parser.add_argument(
        "-v", "--version", action="version", version=f"%(prog)s {__version__}"
    )
    return parser.parse_args()


def read_sample(path):
    """Read one sample file, with consistent types for the coordinate columns."""
    df = pd.read_csv(path, index_col=0, low_memory=False)
    return df.astype({"chr": str, "start": int, "end": int})


def merge_samples(paths, how):
    """Join all sample files on the region coordinates."""
    join = "inner" if how == "inner" else "outer"

    merged = read_sample(paths[0])
    for path in paths[1:]:
        merged = merged.merge(read_sample(path), on=COORDINATES, how=join)

    if how == "outer_fillna":
        merged = merged.fillna(0)
    return merged


def column_sort_key(name):
    """Sort key that groups the columns of each sample together.

    Columns are ordered by sample name (the part before the last '_'), with the
    '_meth' column before the '_depth' column of the same sample, and the full
    column name as a tie-breaker.
    """
    sample = name.rsplit("_", 1)[0]
    return (sample, "_meth" not in name, "_depth" in name, name)


def sort_matrix(df):
    """Order the value columns by sample and the rows by genomic position."""
    value_columns = sorted(
        (col for col in df.columns if col not in COORDINATES), key=column_sort_key
    )
    return (
        df[COORDINATES + value_columns]
        .sort_values(by=COORDINATES)
        .reset_index(drop=True)
    )


def to_celfie_atlas(df):
    """Collapse the samples per entity by summing their counts.

    A column such as '<entity>_<sample>_meth' is renamed to '<entity>_meth' and
    all the columns sharing that name are summed, giving one '_meth' and one
    '_depth' column per entity (in order of first appearance).
    """
    entity_columns = {}
    for col in df.columns.drop(COORDINATES):
        parts = col.split("_")
        entity_columns.setdefault(f"{parts[0]}_{parts[-1]}", []).append(col)

    summed = {entity: df[cols].sum(axis=1) for entity, cols in entity_columns.items()}
    return pd.concat([df[COORDINATES], pd.DataFrame(summed)], axis=1)


def main():
    args = parse_arguments()

    matrix = sort_matrix(merge_samples(args.file_paths.split(), args.how))

    if args.celfie_atlas:
        to_celfie_atlas(matrix).to_csv(f"final_{args.outfile}")
    else:
        matrix.to_csv(args.outfile)


if __name__ == "__main__":
    main()
