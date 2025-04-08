# Structural Connectivity Analysis

## Overview
This repository contains two scripts: `tractography.sh` for processing diffusion MRI data to perform tractography and generate the connectivity matrix and `count_streamlines.sh` for processing the tractogram and calculating the number of streamlines for each ROI of an atlas. 


## Table of Contents
1. [Software Prerequisites](#software-prerequisites)
2. [Input Requirements](#input-requirements)
3. [Usage](#usage)
   - [Running Tractography](#running-tractography)
   - [Running Count Streamlines](#running-count-streamlines)
4. [Notes](#notes)
5. [Troubleshooting](#troubleshooting)
6. [Contact](#contact)

## Software Prerequisites
- [MRtrix3](https://www.mrtrix.org/) (we used version 3.0.3)
- [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki) (we used version 6.0.5)

## Input Requirements
The scripts can require the following inputs:
1. DWI: Diffusion-weighted image (in NIFTI format, multi-shell)
2. BVEC: b-vector file
3. BVAL: b-value file
4. ANAT: Structural image (e.g., T1-weighted, in NIFTI format)
5. ATLAS: Atlas file in standard space (in NIFTI format)
6. WARP_STD2STRUCT: Warp of the transformation from standard space to structural space (in NIFTI format)
7. TRACT_FILE: tract file (.tck)
8. REMOVE_TEMP: Flag (0 or 1) for removing temporary files

## Usage

First, make sure that the scripts have the right permisison to be run, by using chmod:
```bash
chmod 755 tractography.sh
chmod 755 count_streamlines.sh
```

### Running Tractography
```bash
./tractography.sh <DWI> <BVEC> <BVAL> <ANAT> <ATLAS> <WARP_STD2STRUCT> <REMOVE_TEMP>
```

Example:
```bash
./tractography.sh subject1_dwi.nii.gz subject1_dwi.bvec subject1_dwi.bval subject1_t1.nii.gz atlas.nii.gz subject1_std2struct_warp.nii.gz 1
```

### Running Count Streamlines
```bash
./count_streamlines.sh <DWI> <ANAT> <WARP_STD2STRUCT> <ATLAS> <TRACKS_FILE> <REMOVE_TEMP>
```

Example:
```bash
./count_streamlines.sh subject1_dwi.nii.gz subject1_t1.nii.gz subject1_std2struct_warp.nii.gz atlas.nii.gz tracts.tck 1
```

## Notes
- For multi-shell acquisitions, the script uses the "dhollander" method for response function estimation. Other methods might be suited depending on the acquisition. For single-shell acquisitions, it is recommended to change to the "tournier" method.
- For single-shell acquisitions, the `dwi2fod` function should use the "csd" methods instead of the "msmt_csd".
- In the `5ttgen` function, it is imperative to use the `-nocrop` flag so that the output image has the same size as the input image. Additionally, the `-premasked` flag was used since the T1 image was already skull-stripped.

## Troubleshooting
- Ensure all input files exist and are in the correct format.
- Check if FSL and MRtrix3 are correctly installed and available in your path. MRtrix3 can run into some issues with Python>=3.10, with failed imports being the main symptom. If that's the case, downgrade to, at most, python3.9.
- For coregistration, do a manual inspection of intermediate images.
- If you find some other problem, feel free to create an issue.

## Contact
For questions or other business contact [@anamatoso](https://github.com/anamatoso)

If you use this code in your research, please cite this repository or [this paper](https://github.com/anamatoso/connectivity-analysis-diffusion).
