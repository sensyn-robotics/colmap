#!/bin/sh
# This is a script for run all the stuff for ACSL.inc's data.
# Author: Masahiro Ogawa
###

SCRIPT=$(realpath $0)
TOPDIR=$(dirname $SCRIPT)/../..

cd ${TOPDIR}/docker
./build.sh ${TOPDIR}
