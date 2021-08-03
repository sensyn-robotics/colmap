#!/bin/sh
# Description: This is a shell script to run SfM and georegistration for ACSL data.
# Author: Masahiro Ogawa @Sensyn-robotics
# How to use:
# 1. put input images into colmap/images
# 2. create a directory named colmap/work
# 3. put acsl camera position file "poslog.csv" into colmap/work
# 4. run this script

# run colmap
colmap automatic_reconstructor --image_path images --workspace_path work --single_camera 1

# get camera positions as a text file.
colmap model_converter --input_path work/sparse/0 --output_path work/sparse/0 --output_type TXT

# create camera positions from acsl poslog.csv
python3 scripts/python/poslog2campose.py

# coordinate transform(georegistration) the result
colmap model_aligner --input_path work/sparse/0/ --output_path work/georegistration/ --ref_images_path work/campose.txt --robust_alignment 1 --robust_alignment_max_error 0.01


# ref: https://docs.google.com/document/d/1HNBnTp5Pt0Uhjx4pQLLET6IGIG2u2Vouf7yjjDTPK_s
