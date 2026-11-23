#!/usr/bin/env python3
"""Run MetDecode on the DecoNFlow (CelFiE-like) input files.

The MetDecode model comes from the bioconda package ``metdecode``
(https://github.com/JorisVermeeschLab/MetDecode, Antoine Passemiers, MIT License).
This wrapper replaces the ``metdecode`` command line (``metdecode.cli``) to:
  - read comma-separated files with an index column and lowercase headers
    (``chr``, ``start``, ``end``, ``<cell type>_meth``, ``<cell type>_depth``),
    the CelFiE-like format of the pipeline, instead of the tab-separated files
    with ``CHROM``, ``START``, ``END``, ``_METH`` and ``_DEPTH`` columns;
  - accept the X and Y chromosomes when the names have no ``chr`` prefix;
  - write the cell type proportions as fractions (0-1) instead of percentages.
The rest (checks, model and options) is the same as ``metdecode.cli``.
"""
import argparse
import os

import numpy as np
import pandas as pd

from metdecode.model import MetDecode


def chr_name_to_int(chr_name: str) -> int:
    """Convert a chromosome name (e.g. "chr8", "8", "chrX" or "X") to a 0-based identifier."""
    chr_name = chr_name.lower()
    if chr_name.startswith('chr'):
        chr_name = chr_name[3:]
    if chr_name == 'x':
        chr_id = 23
    elif chr_name == 'y':
        chr_id = 24
    else:
        chr_id = int(chr_name)
    return chr_id - 1


def row_name_as_int(combined_coords: str) -> int:
    """Convert coordinates of the form "chr1-3792834-3793456" to an integer used to sort the regions."""
    elements = combined_coords.split('-')
    assert len(elements) == 3
    return 1000000000 * chr_name_to_int(elements[0]) + int(elements[1])


def load_input_file(filepath: str):
    """Load a CelFiE-like CSV file of read counts.

    The file has an index column, then the ``chr``, ``start`` and ``end`` columns of the
    regions, then two columns per sample / cell type: ``<name>_meth`` (methylated counts)
    and ``<name>_depth`` (total counts).

    Returns:
        methylated: matrix of shape `(n_samples, n_markers)` with the methylated counts.
        depths: matrix of shape `(n_samples, n_markers)` with the total counts.
        column_names: sample / cell type names.
        row_names: region names ("chr-start-end"), sorted by genomic coordinates.
    """
    # Check the presence of the header
    with open(filepath, 'r') as f:
        header = 'infer' if f.readline().startswith(',chr') else None

    df = pd.read_csv(filepath, index_col=0, header=header)
    row_names = df.iloc[:, 0].astype(str) + '-' + df.iloc[:, 1].astype(str) + '-' + df.iloc[:, 2].astype(str)

    values = df.iloc[:, 3:].values.T
    methylated = values[::2, :].astype(float)
    depths = values[1::2, :].astype(int)

    if header is not None:
        column_names = [s.replace('_meth', '') for s in df.columns[3::2]]
    else:
        column_names = [f'sample-{j + 1}' for j in range(depths.shape[0])]
    column_names = np.asarray(column_names, dtype=object)
    row_names = np.asarray(row_names, dtype=object)

    # Sort marker regions by increasing genomic coordinates
    idx = np.argsort(np.asarray([row_name_as_int(row_name) for row_name in row_names], dtype=np.uint64))
    row_names = row_names[idx]
    methylated = methylated[:, idx]
    depths = depths[:, idx]

    # Ensure methylation ratios are within bounds [0, 1]
    methylated = np.clip(methylated, 0, depths)

    return methylated, depths, column_names, row_names


def parse_arguments():
    parser = argparse.ArgumentParser(description='MetDecode deconvolution on CelFiE-like CSV files.')
    parser.add_argument('atlas-filepath', type=str, help='Reference atlas (CSV) in the CelFiE format')
    parser.add_argument('cfdna-filepath', type=str, help='Bulk samples (CSV) in the CelFiE format')
    parser.add_argument('out-filepath', type=str, help='Where to write the deconvolution results as CSV file')
    parser.add_argument('-n-unknown-tissues', type=int, default=0,
                        help='Number of unknown tissues to infer and add to the atlas')
    parser.add_argument('--no-coverage', action='store_true', help='Whether to disable the modeling of coverage')
    parser.add_argument('--supervised', action='store_true', help='Whether to disable unsupervised deconvolution')
    parser.add_argument('--sum1', action='store_true', help='Whether cell type proportions should sum up to one')
    return parser.parse_args()


def main():
    args = parse_arguments()
    atlas_filepath = getattr(args, 'atlas-filepath')
    cfdna_filepath = getattr(args, 'cfdna-filepath')
    out_filepath = getattr(args, 'out-filepath')

    folder = os.path.dirname(out_filepath)
    if folder and not os.path.isdir(folder):
        os.makedirs(folder)

    M_atlas, D_atlas, cell_type_names, marker_names = load_input_file(atlas_filepath)
    M_cfdna, D_cfdna, sample_names, marker_names2 = load_input_file(cfdna_filepath)
    for marker1, marker2 in zip(marker_names, marker_names2):
        marker1 = marker1.split('-')
        marker2 = marker2.split('-')
        if (marker1[0] != marker2[0]) or (marker1[1] != marker2[1]):
            raise ValueError(f'Marker regions differ in the two input files: {marker1} and {marker2}')

    assert np.less_equal(M_cfdna, D_cfdna).all()
    assert np.less_equal(M_atlas, D_atlas).all()
    assert M_cfdna.shape[1] == M_atlas.shape[1]
    assert M_cfdna.shape == D_cfdna.shape
    assert M_atlas.shape == D_atlas.shape

    print(f'Input atlas file        : {atlas_filepath}')
    print(f'Input cfdna file        : {cfdna_filepath}')
    print(f'Output file             : {out_filepath}')
    print('Number of cfDNA profiles       : %i' % M_cfdna.shape[0])
    print('Number of tissues in the atlas : %i' % M_atlas.shape[0])
    print('Number of markers              : %i' % M_atlas.shape[1])

    model = MetDecode(
        M_atlas,
        D_atlas,
        M_cfdna,
        D_cfdna,
        n_unknown_tissues=args.n_unknown_tissues,
        coverage=not args.no_coverage,
        unsupervised=not args.supervised,
        sum1=args.sum1
    )
    alpha = model.deconvolute()

    # alpha[i, j] is the fraction of cell type j in sample i
    with open(out_filepath, 'w') as f:
        f.write(','.join(['Sample'] + list(cell_type_names) + [f'Unknown{i + 1}' for i in range(args.n_unknown_tissues)]) + '\n')
        for i, sample_name in enumerate(sample_names):
            f.write(sample_name)
            for value in alpha[i, :]:
                f.write(f',{value:.3f}')
            f.write('\n')
    print(f'Deconvolution results stored at {out_filepath}.')


if __name__ == '__main__':
    main()
