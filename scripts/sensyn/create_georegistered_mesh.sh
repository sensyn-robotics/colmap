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

# Debug: Check paths and directories
echo "[DEBUG] DATASETDIR: $DATASETDIR"
echo "[DEBUG] WORKDIR: $WORKDIR"
echo "[DEBUG] Checking for images..."
ls -la "$DATASETDIR/images/" | head -5
echo "[DEBUG] Total images found: $(find "$DATASETDIR/images" -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" | wc -l)"
echo "[DEBUG] Checking for metadata..."
ls -la "$DATASETDIR/metadata.json" 2>/dev/null || echo "No metadata.json found"


echo "[INFO] start sparse reconstruction."

# Debug: Check image properties
echo "[DEBUG] Analyzing image dataset..."
FIRST_IMAGE=$(ls "$DATASETDIR/images"/*.jpg 2>/dev/null | head -1)
if [ -n "$FIRST_IMAGE" ]; then
    if command -v identify >/dev/null 2>&1; then
        echo "[DEBUG] Sample image info: $(identify "$FIRST_IMAGE")"
    fi
fi

# Debug: Check for potential issues
echo "[DEBUG] Checking for common issues..."
SMALL_IMAGES=$(find "$DATASETDIR/images" -name "*.jpg" -exec sh -c 'size=$(wc -c < "$1"); [ $size -lt 100000 ] && echo "$1"' _ {} \; | wc -l)
echo "[DEBUG] Found $SMALL_IMAGES images smaller than 100KB (might be too small)"

# Extract features with more liberal settings for challenging images
colmap feature_extractor \
   --database_path $WORKDIR/database.db \
   --image_path $DATASETDIR/images \
   --ImageReader.single_camera 1

# Check feature extraction results
echo "[INFO] Checking feature extraction results..."
FEATURE_COUNT=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM keypoints;")
AVG_FEATURES=$(sqlite3 $WORKDIR/database.db "SELECT AVG(rows) FROM keypoints WHERE rows > 0;")
echo "[INFO] Total keypoints extracted: $FEATURE_COUNT"
echo "[INFO] Average features per image: $AVG_FEATURES"

if [ "$FEATURE_COUNT" -lt "10000" ]; then
    echo "[WARNING] Low feature count detected. Images may be blurry or lack texture."
fi

# Try sequential matching first (better for video sequences like Record3D)
echo "[INFO] Trying sequential matching for video-like sequences..."
colmap sequential_matcher \
   --database_path $WORKDIR/database.db 

# Check if we got enough matches from sequential matching
echo "[INFO] Checking match results..."
MATCH_COUNT=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM matches WHERE rows > 15;")
echo "[INFO] Found $MATCH_COUNT image pairs with >15 matches"

# If we don't have enough matches, try exhaustive matching
if [ "$MATCH_COUNT" -lt "10" ]; then
    echo "[INFO] Sequential matching insufficient, trying exhaustive matching..."
    colmap exhaustive_matcher \
       --database_path $WORKDIR/database.db \
       --SiftMatching.guided_matching 1 \
       --SiftMatching.max_ratio 0.8 \
       --SiftMatching.max_distance 0.7
    
    # Check again
    MATCH_COUNT=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM matches WHERE rows > 15;")
    echo "[INFO] After exhaustive matching: $MATCH_COUNT image pairs with >15 matches"
fi

mkdir -p $WORKDIR/sparse

# Run mapper with more liberal settings for challenging datasets
echo "[INFO] Starting 3D reconstruction..."
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

# Check if sparse reconstruction was successful
if [ ! -d "${WORKDIR}/sparse/0" ] || [ ! -f "${WORKDIR}/sparse/0/cameras.bin" ]; then
    echo "[ERROR] Sparse reconstruction failed. No 3D model was created."
    echo "[ERROR] This usually means:"
    echo "  1. Images don't have enough overlap"
    echo "  2. Images are too blurry or low quality" 
    echo "  3. Scene lacks distinctive features"
    echo "[INFO] Check your images and try with different parameters"
    exit 1
fi

# Use model_aligner with required max_error parameter
colmap model_aligner \
    --input_path ${WORKDIR}/sparse/0 \
    --output_path ${WORKDIR}/sparse/${GEOREGIDIR} \
    --ref_images_path ${WORKDIR}/campose.txt \
    --max_error 5.0


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
