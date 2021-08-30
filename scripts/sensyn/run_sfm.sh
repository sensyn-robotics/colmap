#!/bin/sh
# Description: This is a shell script to run SfM and georegistration for ACSL.inc's data.
# Author: Masahiro Ogawa @Sensyn-robotics
# How to use:
# 1. put input images into <your working directory>/dataset/images (e.g. colmap/dataset/images)
# 2. put ACSL.inc's camera position file "poslog.csv" into <your working directory>/dataset/ (e.g. colmap/dataset)
# 3. run this script

SCRIPT=$(realpath $0)
TOPDIR=$(dirname $SCRIPT)/../..

# run all
${TOPDIR}/scripts/sensyn/create_georegistered_mesh.sh ${TOPDIR}/dataset
