#!/bin/sh
# Description: This is a shell script to run SfM and georegistration for ACSL.inc's data.
# Author: Masahiro Ogawa @Sensyn-robotics
# How to use:
# 1. put input images into <your working directory>/images (e.g. colmap/images)
# 2. put ACSL.inc's camera position file "poslog.csv" into <your working directory>/work (e.g. colmap/work)
# 3. run this script


# run colmap
colmap automatic_reconstructor --image_path images --workspace_path work --single_camera 1

# get camera positions as a text file.
colmap model_converter --input_path work/sparse/0 --output_path work/sparse/0 --output_type TXT

# create camera positions from acsl poslog.csv
python3 scripts/sensyn/poslog2campose.py

# coordinate transform(georegistration) the result
mkdir -p work/georegistration
colmap model_aligner --input_path work/sparse/0/ --output_path work/georegistration/ --ref_images_path work/campose.txt --robust_alignment 1 --robust_alignment_max_error 0.01


# ref: https://docs.google.com/document/d/1HNBnTp5Pt0Uhjx4pQLLET6IGIG2u2Vouf7yjjDTPK_s
