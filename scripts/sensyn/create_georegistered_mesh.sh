#!/bin/sh
# This is a script for COLMAP georegistration and then run dense reconstruction
####

USAGE="$0 <work directory which have images/, <poslog.csv or metadata.json> >
The project directory must contain a directory named images with all the images."

if [ $# -lt 1 ]; then
    echo $USAGE
    exit 1
fi

SCRIPT=$(realpath $0)
TOPDIR=$(dirname $SCRIPT)/../..


echo "[INFO] create_georegistered_mesh.sh: start processing."

DATASETDIR=$1 #data directory which has images dir, and poslog.csv.
WORKDIR=${DATASETDIR}/work # output directory
mkdir -p ${WORKDIR}


echo "[INFO] start sparse reconstruction."

colmap feature_extractor \
   --database_path $WORKDIR/database.db \
   --image_path $DATASETDIR/images \
   --ImageReader.single_camera 1

colmap exhaustive_matcher \
   --database_path $WORKDIR/database.db

mkdir -p $WORKDIR/sparse

colmap mapper \
    --database_path $WORKDIR/database.db \
    --image_path $DATASETDIR/images \
    --output_path $WORKDIR/sparse


echo "[INFO] get camera positions as a text file"
colmap model_converter --input_path ${WORKDIR}/sparse/0 --output_path ${WORKDIR}/sparse/0 --output_type TXT


if [ -f "${DATASETDIR}/poslog.csv" ]; then
    echo "[INFO] create camera positions file work/campose.txt from acsl poslog.csv"
    python3 scripts/sensyn/poslog2campose.py "${DATASETDIR}"
elif [ -f "${DATASETDIR}/metadata.json" ]; then
    echo "[INFO] create camera positions file work/campose.txt from Record3D metadata.json"
    python3 scripts/sensyn/record3d_to_campose.py "${DATASETDIR}"
else
    echo "[ERROR] No poslog.csv or metadata.json found in ${DATASETDIR}"
    exit 1
fi

echo "[INFO] georegistrate sparse point cloud"
GEOREGIDIR=georegistration
mkdir -p ${WORKDIR}/sparse/${GEOREGIDIR}
colmap model_aligner --input_path ${WORKDIR}/sparse/0 --output_path ${WORKDIR}/sparse/${GEOREGIDIR} --ref_images_path ${WORKDIR}/campose.txt --robust_alignment 1 --robust_alignment_max_error 0.01


echo "[INFO] dense reconstruciton for georegistered data"
mkdir -p $WORKDIR/dense

colmap image_undistorter \
    --image_path $DATASETDIR/images \
    --input_path $WORKDIR/sparse/${GEOREGIDIR} \
    --output_path $WORKDIR/dense/${GEOREGIDIR} \
    --output_type COLMAP \
    --max_image_size 2000

colmap patch_match_stereo \
    --workspace_path $WORKDIR/dense/${GEOREGIDIR} \
    --workspace_format COLMAP \
    --PatchMatchStereo.geom_consistency true

colmap stereo_fusion \
    --workspace_path $WORKDIR/dense/${GEOREGIDIR} \
    --workspace_format COLMAP \
    --input_type geometric \
    --output_path $WORKDIR/dense/${GEOREGIDIR}/fused.ply

colmap poisson_mesher \
    --input_path $WORKDIR/dense/${GEOREGIDIR}/fused.ply \
    --output_path $WORKDIR/dense/${GEOREGIDIR}/meshed-poisson.ply

colmap delaunay_mesher \
    --input_path $WORKDIR/dense/${GEOREGIDIR} \
    --output_path $WORKDIR/dense/${GEOREGIDIR}/meshed-delaunay.ply
