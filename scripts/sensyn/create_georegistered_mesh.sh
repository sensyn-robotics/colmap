#!/bin/sh
# This is a script for COLMAP georegistration and then run dense reconstruction
####

USAGE="$0 <work directory which have images/, <poslog.csv or metadata.json> >
The project directory must contain a directory named images with all the images."

if [ $# -lt 1 ]; then
    echo $USAGE
    exit 1
fi

echo "[INFO] Start processing."

SCRIPT=$(realpath $0)
TOPDIR=$(dirname $SCRIPT)/../..
DATASETDIR=$1 #data directory which has images dir, and poslog.csv.
WORKDIR=${DATASETDIR}/work # output directory
mkdir -p ${WORKDIR}

echo "[INFO] Checking inputs..."
echo "[DEBUG] DATASETDIR: $DATASETDIR"
echo "[DEBUG] WORKDIR: $WORKDIR"
echo "[DEBUG] Checking for images..."
ls -la "$DATASETDIR/images/" | head -5
echo "[DEBUG] Total images found: $(find "$DATASETDIR/images" -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" | wc -l)"
echo "[DEBUG] Checking for metadata..."
ls -la "$DATASETDIR/metadata.json" 2>/dev/null || echo "No metadata.json found"
FIRST_IMAGE=$(ls "$DATASETDIR/images"/*.jpg 2>/dev/null | head -1)
if [ -n "$FIRST_IMAGE" ]; then
    if command -v identify >/dev/null 2>&1; then
        echo "[DEBUG] Sample image info: $(identify "$FIRST_IMAGE")"
    fi
fi
SMALL_IMAGES=$(find "$DATASETDIR/images" -name "*.jpg" -exec sh -c 'size=$(wc -c < "$1"); [ $size -lt 100000 ] && echo "$1"' _ {} \; | wc -l)
echo "[DEBUG] Found $SMALL_IMAGES images smaller than 100KB (might be too small)"


echo "[INFO] === Start sparse reconstruction ==="
echo "[INFO] Start feature extraction..."
colmap feature_extractor \
   --database_path $WORKDIR/database.db \
   --image_path $DATASETDIR/images \
   --ImageReader.single_camera 1 \
   --SiftExtraction.max_image_size 1200 \
   --SiftExtraction.max_num_features 4096 \
   --SiftExtraction.use_gpu 1

echo "[INFO] Checking feature extraction results..."
FEATURE_COUNT=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM keypoints;")
AVG_FEATURES=$(sqlite3 $WORKDIR/database.db "SELECT AVG(rows) FROM keypoints WHERE rows > 0;")
echo "[INFO] Total keypoints extracted: $FEATURE_COUNT"
echo "[INFO] Average features per image: $AVG_FEATURES"
if [ "$FEATURE_COUNT" -lt "10000" ]; then
    echo "[WARNING] Low feature count detected. Images may be blurry or lack texture."
fi

echo "[INFO] Trying sequential matching for video-like sequences..."
colmap sequential_matcher \
   --database_path $WORKDIR/database.db 

echo "[INFO] Check if we got enough matches from sequential matching..."
MATCH_COUNT=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM matches WHERE rows > 15;")
echo "[INFO] Found $MATCH_COUNT image pairs with >15 matches"

if [ "$MATCH_COUNT" -lt "10" ]; then
    echo "[INFO] Sequential matching insufficient, trying exhaustive matching..."
    colmap exhaustive_matcher \
       --database_path $WORKDIR/database.db \
       --SiftMatching.guided_matching 1 \
       --SiftMatching.max_ratio 0.8 \
       --SiftMatching.max_distance 0.7 \
       --SiftMatching.max_num_matches 8192 
    
    MATCH_COUNT=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM matches WHERE rows > 15;")
    echo "[INFO] After exhaustive matching: $MATCH_COUNT image pairs with >15 matches"
    
    if [ "$MATCH_COUNT" -lt "5" ]; then
        echo "[WARNING] Still very few matches after exhaustive matching."
        echo "[WARNING] Trying with relaxed matching parameters..."
        colmap exhaustive_matcher \
           --database_path $WORKDIR/database.db \
           --SiftMatching.guided_matching 0 \
           --SiftMatching.max_ratio 0.9 \
           --SiftMatching.max_distance 0.8 \
           --SiftMatching.max_num_matches 16384 
        
        FINAL_MATCH_COUNT=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM matches WHERE rows > 10;")
        echo "[INFO] After relaxed matching: $FINAL_MATCH_COUNT image pairs with >10 matches"
    fi
fi


echo "[INFO] Starting 3D reconstruction..."
echo "[DEBUG] Checking match quality before reconstruction..."
TOTAL_MATCHES=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM matches;")
GOOD_MATCHES=$(sqlite3 $WORKDIR/database.db "SELECT COUNT(*) FROM matches WHERE rows > 15;")
echo "[DEBUG] Total image pairs: $TOTAL_MATCHES"
echo "[DEBUG] Good matches (>15 features): $GOOD_MATCHES"
if [ "$GOOD_MATCHES" -lt "5" ]; then
    echo "[WARNING] Very few good matches ($GOOD_MATCHES). Reconstruction may fail."
    echo "[WARNING] This often happens with:"
    echo "  - Images taken from too similar viewpoints"
    echo "  - Low-texture scenes (sky, walls, water)"
    echo "  - Motion blur or poor lighting"
fi

mkdir -p $WORKDIR/sparse
colmap mapper \
    --database_path $WORKDIR/database.db \
    --image_path $DATASETDIR/images \
    --output_path $WORKDIR/sparse \
    --Mapper.ba_global_max_num_iterations 25 \
    --Mapper.ba_global_max_refinements 2 \
    --Mapper.ba_local_max_num_iterations 15 \
    --Mapper.ba_local_num_images 4 \
    --Mapper.multiple_models false \
    --Mapper.max_num_models 1 \
    --Mapper.num_threads 16 \
    --Mapper.ba_use_gpu 1

# Check if sparse reconstruction was successful
if [ ! -d "$WORKDIR/sparse/0" ] || [ ! -f "$WORKDIR/sparse/0/cameras.bin" ]; then
    echo "[ERROR] Sparse reconstruction failed. No 3D model was created."
    echo "[ERROR] Common causes and solutions:"
    echo "  1. Images don't have enough overlap (need 60-80% overlap)"
    echo "  2. Images are too blurry or low quality"
    echo "  3. Scene lacks distinctive features (try textured objects)"
    echo "  4. Try different feature extraction settings:"
    echo "     - Reduce --SiftExtraction.max_image_size (try 800)"
    echo "     - Increase --SiftExtraction.max_num_features (try 8192)"
    echo "     - Try --SiftExtraction.use_gpu 0 if GPU fails"
    echo "  5. For video sequences, ensure images are from different viewpoints"
    echo "[INFO] Debug: Check your images with: ls -la \${DATASETDIR}/images/ | head -10"
    echo "[INFO] Debug: Check database contents with: sqlite3 \${WORKDIR}/database.db"
    echo "[INFO] Debug: Check feature matches with: 'SELECT COUNT(*) FROM matches;'"
    exit 1
fi

echo "[INFO] get camera positions as a text file"
colmap model_converter --input_path ${WORKDIR}/sparse/0 --output_path ${WORKDIR}/sparse/0 --output_type TXT


if [ -f "${DATASETDIR}/poslog.csv" ]; then
    echo "[INFO] create camera positions file work/campose.txt from acsl poslog.csv"
    if ! command -v python3 >/dev/null 2>&1; then
        echo "[ERROR] python3 is not installed. Cannot process poslog.csv"
        echo "[ERROR] Run the container with start_sensyn_docker.sh to install dependencies"
        exit 1
    fi
    if [ ! -f "scripts/sensyn/poslog2campose.py" ]; then
        echo "[ERROR] poslog2campose.py script not found in scripts/sensyn/"
        exit 1
    fi
    if ! python3 scripts/sensyn/poslog2campose.py "${DATASETDIR}"; then
        echo "[ERROR] Failed to convert poslog.csv to campose.txt"
        echo "[ERROR] Check if pandas is installed: python3 -c 'import pandas'"
        exit 1
    fi
elif [ -f "${DATASETDIR}/metadata.json" ]; then
    echo "[INFO] create camera positions file work/campose.txt from Record3D metadata.json"
    if ! command -v python3 >/dev/null 2>&1; then
        echo "[ERROR] python3 is not installed. Cannot process metadata.json"
        echo "[ERROR] Run the container with start_sensyn_docker.sh to install dependencies"
        exit 1
    fi
    if [ ! -f "scripts/sensyn/record3d_to_campose.py" ]; then
        echo "[ERROR] record3d_to_campose.py script not found in scripts/sensyn/"
        exit 1
    fi
    if ! python3 scripts/sensyn/record3d_to_campose.py "${DATASETDIR}"; then
        echo "[ERROR] Failed to convert metadata.json to campose.txt"
        echo "[ERROR] Check if python3 is installed and the script exists"
        exit 1
    fi
else
    echo "[ERROR] No poslog.csv or metadata.json found in ${DATASETDIR}"
    exit 1
fi

# Check if campose.txt was created successfully
if [ ! -f "${WORKDIR}/campose.txt" ]; then
    echo "[ERROR] Failed to create campose.txt file"
    echo "[ERROR] Georegistration cannot proceed without camera positions"
    exit 1
fi

echo "[INFO] Georegistrate sparse point cloud"
GEOREGIDIR=georegistration
mkdir -p ${WORKDIR}/sparse/${GEOREGIDIR}

# Determine coordinate system based on metadata source
if [ -f "${DATASETDIR}/poslog.csv" ]; then
    echo "[INFO] Using GPS coordinates from poslog.csv"
    REF_IS_GPS=1
elif [ -f "${DATASETDIR}/metadata.json" ]; then
    echo "[INFO] Using local coordinates from Record3D metadata.json"
    REF_IS_GPS=0
else
    echo "[ERROR] No metadata source found"
    exit 1
fi

echo "[INFO] Running model_aligner for georegistration (ref_is_gps=$REF_IS_GPS)..."
if colmap model_aligner \
    --input_path ${WORKDIR}/sparse/0 \
    --output_path ${WORKDIR}/sparse/${GEOREGIDIR} \
    --ref_images_path ${WORKDIR}/campose.txt \
    --ref_is_gps $REF_IS_GPS \
    --alignment_max_error 5.0; then
    echo "[INFO] ✅ Georegistration completed successfully"
else
    echo "[ERROR] ❌ Georegistration failed!"
    echo "[ERROR] This usually means:"
    echo "  1. Camera positions in metadata don't match COLMAP reconstruction"
    echo "  2. Coordinate system mismatch between metadata and images"
    echo "  3. Too few matching images between metadata and reconstruction"
    echo "[ERROR] Check your metadata file and image timestamps"
    exit 1
fi

# Verify georegistration output exists
if [ ! -d "${WORKDIR}/sparse/${GEOREGIDIR}" ] || [ ! -f "${WORKDIR}/sparse/${GEOREGIDIR}/cameras.bin" ]; then
    echo "[ERROR] Georegistration output missing. Cannot proceed with dense reconstruction."
    echo "[INFO] Available files in sparse directory:"
    ls -la ${WORKDIR}/sparse/
    exit 1
fi


echo "[INFO] Start dense reconstruction for georegistered data"
mkdir -p $WORKDIR/dense

echo "[INFO] Step 1: Image undistortion and rectification..."
if colmap image_undistorter \
    --image_path $DATASETDIR/images \
    --input_path $WORKDIR/sparse/${GEOREGIDIR} \
    --output_path $WORKDIR/dense/${GEOREGIDIR} \
    --output_type COLMAP \
    --max_image_size 1000; then
    echo "[INFO] ✅ Image undistortion completed"
else
    echo "[ERROR] ❌ Image undistortion failed"
    echo "[ERROR] Try with smaller --max_image_size (e.g., 800)"
    exit 1
fi

echo "[INFO] Step 2: Patch match stereo (dense matching)..."
if colmap patch_match_stereo \
    --workspace_path $WORKDIR/dense/${GEOREGIDIR} \
    --workspace_format COLMAP \
    --PatchMatchStereo.geom_consistency true \
    --PatchMatchStereo.max_image_size 1000; then
    echo "[INFO] ✅ Patch match stereo completed"
else
    echo "[ERROR] ❌ Patch match stereo failed"
    echo "[ERROR] This is often due to GPU memory issues. Try:"
    echo "  1. Reduce --max_image_size to 800"
    echo "  2. Use CPU mode by removing GPU-related flags"
    echo "  3. Process fewer images at once"
    exit 1
fi

echo "[INFO] Step 3: Stereo fusion (point cloud generation)..."
if colmap stereo_fusion \
    --workspace_path $WORKDIR/dense/${GEOREGIDIR} \
    --workspace_format COLMAP \
    --input_type geometric \
    --output_path $WORKDIR/dense/${GEOREGIDIR}/fused.ply; then
    echo "[INFO] ✅ Point cloud (fused.ply) generated"
else
    echo "[ERROR] ❌ Stereo fusion failed"
    echo "[ERROR] Check if patch match stereo generated depth maps"
    exit 1
fi

echo "[INFO] Step 4: Mesh generation..."
echo "[INFO] Creating Poisson mesh..."
if colmap poisson_mesher \
    --input_path $WORKDIR/dense/${GEOREGIDIR}/fused.ply \
    --output_path $WORKDIR/dense/${GEOREGIDIR}/meshed-poisson.ply; then
    echo "[INFO] ✅ Poisson mesh created"
else
    echo "[WARNING] ⚠️  Poisson mesh creation failed, trying Delaunay..."
fi

echo "[INFO] Creating Delaunay mesh..."
if colmap delaunay_mesher \
    --input_path $WORKDIR/dense/${GEOREGIDIR} \
    --output_path $WORKDIR/dense/${GEOREGIDIR}/meshed-delaunay.ply; then
    echo "[INFO] ✅ Delaunay mesh created"
else
    echo "[WARNING] ⚠️  Delaunay mesh creation failed"
fi

echo "[INFO] === DENSE RECONSTRUCTION COMPLETE ==="
echo "[INFO] Results in: $WORKDIR/dense/${GEOREGIDIR}/"
echo "[INFO] Point cloud: fused.ply"
echo "[INFO] Meshes: meshed-poisson.ply, meshed-delaunay.ply"
