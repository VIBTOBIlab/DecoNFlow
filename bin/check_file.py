#!/usr/bin/env python

import pandas as pd
import argparse
import os

def is_tsv(file_path):
    """
    Checks if the file is a valid TSV by verifying if it can be read with a tab delimiter
    and if all rows have the same number of columns.
    """
    try:
        with open(file_path, 'r') as f:
            # Check if the file has a .tsv extension (optional but useful)
            if not (file_path.endswith('.tsv')|file_path.endswith('.bed')):
                print("Warning: File does not have a .tsv or .bed extension.")

            # Read the first few lines to see if they are separated by tabs
            first_line = f.readline()
            if "\t" not in first_line:
                return False, "File does not appear to be tab-separated."

        # Try reading the entire file as a TSV
        df = pd.read_csv(file_path, sep='\t', header=None)

        # Check if the number of columns is consistent across all rows
        expected_col_count = df.shape[1]
        for idx, row in df.iterrows():
            if len(row) != expected_col_count:
                return False, f"Row {idx+1} has an inconsistent number of columns."

        return True, "File appears to be a valid TSV."

    except Exception as e:
        return False, f"Error while reading the file: {str(e)}"


def check_and_convert_tsv_to_csv(tsv_file_path):

    # Check if the file is a valid TSV
    is_valid_tsv, message = is_tsv(tsv_file_path)
    if not is_valid_tsv:
        return f"Error: {message}"

    try:
        # Read the file as a tab-separated file
        df = pd.read_csv(tsv_file_path, sep='\t')

        # Check for missing values (NaNs) in the dataframe
        if df.isnull().values.any():
            return "Error: The file contains missing values (NaNs)."

        # Check if the first three columns are named 'chr', 'start', and 'end'
        if list(df.columns[:3]) != ['chr', 'start', 'end']:
            return "Error: First three columns are not named 'chr', 'start', 'end'."

        # Check if there are at least two additional columns
        if len(df.columns) < 5:
            return "Error: Reference matrix does not have at least two cell types."

        # Check if the additional columns have unique names
        if len(set(df.columns[3:])) != len(df.columns[3:]):
            return "Error: Cell type columns are not uniquely named."

        # Create a new 'region' column by concatenating 'chr', 'start', and 'end'
        df['DMR'] = df['chr'].astype(str) + ':' + df['start'].astype(str) + '-' + df['end'].astype(str)

        # Drop the original 'chr', 'start', and 'end' columns
        df = df.drop(columns=['chr', 'start', 'end'])

        # Reorder columns to place 'region' at the front
        columns = ['DMR'] + df.columns.tolist()[0:-1]
        df = df[columns]

        # If all checks pass, write the data to a CSV file
        df.to_csv("reference.csv", index=False)

        return f"File format is correct. Data has been written to reference.csv"

    except Exception as e:
        return f"Error: {str(e)}"

def main():
    # Create an argument parser
    parser = argparse.ArgumentParser(description="Check a TSV file format and convert it to CSV.")

    # Add arguments for the TSV input file, CSV output file, and other options
    parser.add_argument('tsv_file', type=str, help="Path to the input TSV file")

    # Parse command-line arguments
    args = parser.parse_args()

    # Read the tsv file
    tsv_file_path = args.tsv_file

    print(check_and_convert_tsv_to_csv(tsv_file_path))

if __name__ == "__main__":
    main()
