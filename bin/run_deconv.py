#!/usr/bin/env python3
# deconvolve.py of meth_atlas (https://github.com/nloyfer/meth_atlas), Copyright Yissum Research
# Development Company of the Hebrew University of Jerusalem Ltd.
# Use and distribution of this Technology is subject to the Software Research License included herein
# (see bin/meth_atlas/README.md).
# CHANGED for DecoNFlow: the plotting functions and the default atlas/output paths were removed, the bulk
# samples are read from a CSV with chr, start and end columns (combined into the region IDs of the atlas),
# and the shebang was changed from "#!/usr/bin/python3 -u".
import numpy as np
import pandas as pd
from scipy import optimize
import argparse
import os.path as op
import sys
from multiprocessing import Pool
import math


class Deconvolve:
    def __init__(self, atlas_path, samp_path, out_dir, resid, slim=False):
        self.out_dir = out_dir  # Output dir to save mixture results and plot
        self.slim = slim  # Write results table w\o indexes and header (bool)
        self.resid = resid  # Output residuals as well
        self.out_bname = self.get_bname(samp_path)  # output files path w/o extension

        # Load input files:
        self.atlas = self.load_atlas(atlas_path)  # Atlas
        self.samples = self.load_sample(samp_path)  # Samples to deconvolve

    def get_bname(self, samp_path):
        """
        Compose output files path:
        join the out_dir path with the basename of the samples file
        remove csv and gz extensions.
        """
        base_fname = op.basename(samp_path)

        if base_fname.endswith('.gz'):
            base_fname = op.splitext(base_fname)[0]
        base_fname = op.splitext(base_fname)[0]
        return op.join(self.out_dir, base_fname)

    @staticmethod
    def load_atlas(atlas_path):
        """
        Read the atlas csv file, save data in self.atlas
        :param atlas_path: Path to the atlas csv file
        """
        # validate path:
        # Deconvolve._validate_csv_file(atlas_path)

        # Read atlas, sort it and drop duplicates
        # print('atlas_path', atlas_path)
        df = pd.read_csv(atlas_path)
        df.rename(columns={list(df)[0]: 'acc'}, inplace=True)
        df['acc'] = df['acc'].astype(str)
        df = df.sort_values(by='acc').drop_duplicates(subset='acc').reset_index(drop=True)
        return df

    @staticmethod
    def decon_single_samp(samp, atlas):
        """
        Deconv ng NNLS, to get the mixture coefficients.
        :param samp: a vector of a single sample
        :param atlas: the atlas DadtaFrame
        :return: the mixture coefficients (of size 25)
        """

        name = samp.columns[1]

        # remove missing sites from both sample and atlas:
        data = samp.merge(atlas, on='acc', how='inner').copy().dropna(axis=0)
        if data.empty:
            print('Warning: skipping an empty sample {}'.format(name), file=sys.stderr)
            # print('Dropped {} missing sites'.format(self.atlas.shape[0] - red_atlas.shape[0]))
            return np.nan
        print('{}: {} sites'.format(name, data.shape[0]), file=sys.stderr)
        del data['acc']
        samp = data.iloc[:, 0]
        red_atlas = data.iloc[:, 1:]

        # get the mixture coefficients by deconvolution (non-negative least squares)
        mixture, residual = optimize.nnls(red_atlas, samp)
        mixture /= np.sum(mixture)
        return mixture, residual

    def load_sample(self, samp_path):
        """
        Read samples csv file. Reduce it to the atlas sites, and save data in self.samples
        Note: samples file must contain a header line.
        """

        # validate path:

        samples = pd.read_csv(samp_path, index_col = 0)
        # Create the new index
        samples['acc'] = samples['chr'].astype(str) + ":" + samples['start'].astype(str) + "-" + samples['end'].astype(str)
        samples['acc'] = samples['acc'].astype(str)
        # Drop the original columns if no longer needed
        samples.drop(columns=['chr', 'start', 'end'], inplace=True)
        samples = samples.sort_values(by='acc').drop_duplicates(subset='acc').reset_index(drop=True)
        samples = samples.merge(self.atlas['acc'].to_frame(), how='inner', on='acc')
        # Reorder columns to put 'acc' at the first position
        cols = ['acc'] + [col for col in samples.columns if col != 'acc']
        samples = samples[cols]
        return samples

    def run(self):

        # run deconvolution on all samples in parallel
        processes = []
        with Pool() as p:
            for i, smp_name in enumerate(list(self.samples)[1:]):
                params = (self.samples[['acc', smp_name]], self.atlas)
                processes.append(p.apply_async(Deconvolve.decon_single_samp, params))
            p.close()
            p.join()

        self.samples = self.samples.iloc[:, 1:]

        # collect the results to 'res_table':
        arr = [pr.get() for pr in processes]
        res_table = np.empty((self.atlas.shape[1] - 1, self.samples.shape[1]))
        resids_table = np.empty((self.samples.shape[1], 1))
        for i in range(len(arr)):
            res_table[:, i], resids_table[i] = arr[i]
        df = pd.DataFrame(res_table, columns=self.samples.columns, index=list(self.atlas.columns)[1:]).transpose()

        # Dump results
        out_path = self.out_bname + '_deconv_output.csv'

        if self.slim:   # without indexes and header line
            df.to_csv(out_path, index=None, header=None, float_format='%.3f')
        else:
            df.to_csv(out_path, float_format='%.3f')

        if self.resid:
            rf = pd.DataFrame(resids_table, columns=['Residuals'], index=self.samples.columns)
            rf.to_csv(self.out_bname + '_residuals.csv', float_format='%.3f')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--atlas_path', '-a',
                        help='Path to Atlas csv file.\nThe first column must be'
                             ' Illumina IDs (e.g cg00000029)')

    parser.add_argument('samples_path',
                        help='Path to samples csv file. It must have a header line.\n'
                             'The first column must be Illumina IDs (e.g cg00000029)')

    parser.add_argument('--slim', action='store_true',
                        help='Write the results table *without indexes and header line*')

    parser.add_argument('--residuals', '-r', action='store_true',
                        help='Output residuals to a separate file')

    parser.add_argument('--out_dir', '-o', default='./', help='Output directory')

    args = parser.parse_args()

    Deconvolve(atlas_path=args.atlas_path,
               samp_path=args.samples_path,
               out_dir=args.out_dir,
               resid=args.residuals,
               slim=args.slim).run()


if __name__ == '__main__':
    main()
