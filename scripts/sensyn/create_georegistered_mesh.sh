#!/bin/sh
# This is a script for COLMAP georegistration and then run dense reconstruction
####

USAGE="$0 <work directory which have images/, <poslog.csv or metadata.json> > [--force-all|--force-sparse|--force-geo|--force-dense]

The project directory must contain a directory named images with all the images.

Options:
  --force-all      Force re-run all steps (ignore existing results)
  --force-sparse   Force re-run sparse reconstruction only
  --force-geo      Force re-run georegistration only  
  --force-dense    Force re-run dense reconstruction only
  --help           Show this help message

Without any --force option, existing results will be automatically detected and skipped."

if [ $# -lt 1 ]; then
    echo "$USAGE"
    exit 1
fi

# Check for help first
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "$USAGE"
    exit 0
fi

# Parse arguments
DATASETDIR=$1
FORCE_ALL=false
FORCE_SPARSE=false
FORCE_GEO=false
FORCE_DENSE=false

shift
while [ $# -gt 0 ]; do
    case $1 in
        --force-all)
            FORCE_ALL=true
            FORCE_SPARSE=true
            FORCE_GEO=true
            FORCE_DENSE=true
            ;;
        --force-sparse)
            FORCE_SPARSE=true
            ;;
        --force-geo)
            FORCE_GEO=true
            ;;
        --force-dense)
            FORCE_DENSE=true
            ;;
        --help)
            echo "$USAGE"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "$USAGE"
            exit 1
            ;;
    esac
    shift
done

echo "[INFO] Start processing."
if [ "$FORCE_ALL" = true ]; then
    echo "[INFO] 🔄 FORCE MODE: Re-running all steps (ignoring existing results)"
elif [ "$FORCE_SPARSE" = true ] || [ "$FORCE_GEO" = true ] || [ "$FORCE_DENSE" = true ]; then
    echo "[INFO] 🔄 PARTIAL FORCE MODE: Re-running selected steps"
    [ "$FORCE_SPARSE" = true ] && echo "  - Forcing sparse reconstruction"
    [ "$FORCE_GEO" = true ] && echo "  - Forcing georegistration"
    [ "$FORCE_DENSE" = true ] && echo "  - Forcing dense reconstruction"
else
    echo "[INFO] 🚀 SMART MODE: Automatically skipping completed steps"
    echo "[INFO] Use --force-all to re-run everything, or --help for options"
fi

SCRIPT=$(realpath $0)
TOPDIR=$(dirname $SCRIPT)/../..
#DATASETDIR=$1 #data directory which has images dir, and poslog.csv.
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

# Check if sparse reconstruction already exists
if [ "$FORCE_SPARSE" = false ] && [ -d "$WORKDIR/sparse/0" ] && [ -f "$WORKDIR/sparse/0/cameras.bin" ] && [ -f "$WORKDIR/sparse/0/images.bin" ] && [ -f "$WORKDIR/sparse/0/points3D.bin" ]; then
    echo "[INFO] ✅ Sparse reconstruction already exists, skipping..."
    echo "[INFO] Found existing files: cameras.bin, images.bin, points3D.bin"
    
    # Quick validation of existing sparse reconstruction
    NUM_IMAGES=$(colmap model_converter --input_path ${WORKDIR}/sparse/0 --output_path /tmp --output_type TXT 2>/dev/null && wc -l < /tmp/images.txt || echo "0")
    NUM_POINTS=$(colmap model_converter --input_path ${WORKDIR}/sparse/0 --output_path /tmp --output_type TXT 2>/dev/null && wc -l < /tmp/points3D.txt || echo "0")
    echo "[INFO] Existing sparse model: $NUM_IMAGES registered images, $NUM_POINTS 3D points"
    
    if [ "$NUM_IMAGES" -lt "3" ]; then
        echo "[WARNING] Very few images in sparse reconstruction. Consider using --force-sparse"
    fi
else
    if [ "$FORCE_SPARSE" = true ]; then
        echo "[INFO] 🔄 Force mode: Re-running sparse reconstruction..."
        # Clean up existing sparse results
        rm -rf "$WORKDIR/sparse"
    else
        echo "[INFO] Starting sparse reconstruction..."
    fi
    
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
    
    echo "[INFO] ✅ Sparse reconstruction completed successfully"
fi

echo "[INFO] get camera positions as a text file"
colmap model_converter --input_path ${WORKDIR}/sparse/0 --output_path ${WORKDIR}/sparse/0 --output_type TXT

# Check if campose.txt already exists
if [ "$FORCE_SPARSE" = false ] && [ "$FORCE_GEO" = false ] && [ -f "${WORKDIR}/campose.txt" ]; then
    echo "[INFO] ✅ Camera pose file already exists, skipping conversion..."
    
    # Quick validation
    CAMPOSE_LINES=$(wc -l < "${WORKDIR}/campose.txt")
    echo "[INFO] Existing campose.txt contains $CAMPOSE_LINES lines"
    
    if [ "$CAMPOSE_LINES" -lt "3" ]; then
        echo "[WARNING] Very few camera poses. Consider using --force-geo"
    fi
else
    if [ "$FORCE_SPARSE" = true ] || [ "$FORCE_GEO" = true ]; then
        echo "[INFO] 🔄 Force mode: Re-generating camera poses..."
        rm -f "${WORKDIR}/campose.txt"
    else
        echo "[INFO] Creating camera positions file work/campose.txt..."
    fi
    
    if [ -f "${DATASETDIR}/poslog.csv" ]; then
        echo "[INFO] Converting from ACSL poslog.csv"
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
        echo "[INFO] Converting from Record3D metadata.json"
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
    
    echo "[INFO] ✅ Camera pose file created successfully"
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

# Check if georegistration already exists
if [ "$FORCE_GEO" = false ] && [ -f "${WORKDIR}/sparse/${GEOREGIDIR}/cameras.bin" ] && [ -f "${WORKDIR}/sparse/${GEOREGIDIR}/images.bin" ] && [ -f "${WORKDIR}/sparse/${GEOREGIDIR}/points3D.bin" ]; then
    echo "[INFO] ✅ Georegistration already exists, skipping..."
    echo "[INFO] Found existing georegistered files: cameras.bin, images.bin, points3D.bin"
    
    # Verify the georegistration has reasonable content
    REGISTERED_IMAGES=$(colmap model_converter --input_path ${WORKDIR}/sparse/${GEOREGIDIR} --output_path /tmp --output_type TXT 2>/dev/null && wc -l < /tmp/images.txt || echo "0")
    echo "[INFO] Georegistered model contains $REGISTERED_IMAGES images"
    
    if [ "$REGISTERED_IMAGES" -lt "3" ]; then
        echo "[WARNING] Very few images in georegistered model. Consider using --force-geo"
    fi
else
    if [ "$FORCE_GEO" = true ]; then
        echo "[INFO] 🔄 Force mode: Re-running georegistration..."
        rm -rf "${WORKDIR}/sparse/${GEOREGIDIR}"
        mkdir -p ${WORKDIR}/sparse/${GEOREGIDIR}
    else
        echo "[INFO] Starting georegistration..."
    fi
    
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
    
    echo "[INFO] ✅ Georegistration verification successful"
fi


echo "[INFO] === Start dense reconstruction for georegistered data==="
mkdir -p $WORKDIR/dense

# Check if dense reconstruction is already complete
DENSE_DIR="$WORKDIR/dense/${GEOREGIDIR}"
FINAL_PLY_EXISTS=false
if [ -f "$DENSE_DIR/fused.ply" ]; then
    FINAL_PLY_EXISTS=true
fi
MESHES_EXIST=false
if [ -f "$DENSE_DIR/meshed-poisson.ply" ] || [ -f "$DENSE_DIR/meshed-delaunay.ply" ]; then
    MESHES_EXIST=true
fi

if [ "$FORCE_DENSE" = false ] && [ "$FINAL_PLY_EXISTS" = true ] && [ "$MESHES_EXIST" = true ]; then
    echo "[INFO] ✅ Dense reconstruction already complete, skipping all steps..."
    echo "[INFO] Found existing files:"
    [ -f "$DENSE_DIR/fused.ply" ] && echo "  - Point cloud: fused.ply ($(stat -c%s "$DENSE_DIR/fused.ply" 2>/dev/null | numfmt --to=iec || echo "unknown size"))"
    [ -f "$DENSE_DIR/meshed-poisson.ply" ] && echo "  - Poisson mesh: meshed-poisson.ply ($(stat -c%s "$DENSE_DIR/meshed-poisson.ply" 2>/dev/null | numfmt --to=iec || echo "unknown size"))"
    [ -f "$DENSE_DIR/meshed-delaunay.ply" ] && echo "  - Delaunay mesh: meshed-delaunay.ply ($(stat -c%s "$DENSE_DIR/meshed-delaunay.ply" 2>/dev/null | numfmt --to=iec || echo "unknown size"))"
    echo "[INFO] Dense reconstruction results in: $DENSE_DIR/"
    echo ""
    echo "=== 🎉 PIPELINE COMPLETE (ALL STEPS SKIPPED) ==="
    echo "💡 All reconstruction steps already completed. Use --force options to re-run if needed."
    echo "💡 Load PLY files in MeshLab, CloudCompare, or other 3D software"
    echo "💡 Run diagnostic script if there are issues: ./scripts/sensyn/diagnose_reconstruction.sh $DATASETDIR"
    echo "[INFO] === PIPELINE COMPLETE ==="
    exit 0
fi

if [ "$FORCE_DENSE" = true ]; then
    echo "[INFO] 🔄 Force mode: Re-running dense reconstruction..."
    rm -rf "$DENSE_DIR"
    mkdir -p "$WORKDIR/dense"
fi

# Step 1: Image undistortion and rectification
if [ "$FORCE_DENSE" = false ] && [ -d "$DENSE_DIR" ] && [ -f "$DENSE_DIR/sparse/cameras.bin" ] && [ -f "$DENSE_DIR/sparse/images.bin" ]; then
    echo "[INFO] ✅ Image undistortion already completed, skipping..."
else
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
fi

# Step 2: Patch match stereo (dense matching)
DEPTH_MAPS_COUNT=$(find "$DENSE_DIR/stereo/depth_maps" -name "*.geometric.bin" 2>/dev/null | wc -l)
if [ "$FORCE_DENSE" = false ] && [ "$DEPTH_MAPS_COUNT" -gt 0 ]; then
    echo "[INFO] ✅ Patch match stereo already completed ($DEPTH_MAPS_COUNT depth maps found), skipping..."
else
    echo "[INFO] Step 2: Patch match stereo (dense matching)..."
    colmap patch_match_stereo \
        --workspace_path $WORKDIR/dense/${GEOREGIDIR} \
        --workspace_format COLMAP \
        --PatchMatchStereo.geom_consistency true \
        --PatchMatchStereo.max_image_size 1000
    echo "[INFO] ✅ Patch match stereo completed"
fi

# Step 3: Stereo fusion (point cloud generation)
if [ "$FORCE_DENSE" = false ] && [ -f "$DENSE_DIR/fused.ply" ]; then
    echo "[INFO] ✅ Point cloud (fused.ply) already exists, skipping stereo fusion..."
    PLY_SIZE=$(stat -c%s "$DENSE_DIR/fused.ply" 2>/dev/null || echo "0")
    echo "[INFO] Existing point cloud size: $PLY_SIZE bytes"
else
    echo "[INFO] Step 3: Stereo fusion (point cloud generation)..."
    if colmap stereo_fusion \
        --workspace_path $WORKDIR/dense/${GEOREGIDIR} \
        --workspace_format COLMAP \
        --input_type geometric \
        --output_path $WORKDIR/dense/${GEOREGIDIR}/fused.ply; then
        echo "[INFO] ✅ Point cloud (fused.ply) generated"
        PLY_SIZE=$(stat -c%s "$DENSE_DIR/fused.ply" 2>/dev/null || echo "0")
        echo "[INFO] Generated point cloud size: $PLY_SIZE bytes"
    else
        echo "[ERROR] ❌ Stereo fusion failed"
        echo "[ERROR] Check if patch match stereo generated depth maps"
        exit 1
    fi
fi

# Step 4: Mesh generation
echo "[INFO] Step 4: Mesh generation..."

# Poisson mesh
if [ "$FORCE_DENSE" = false ] && [ -f "$DENSE_DIR/meshed-poisson.ply" ]; then
    echo "[INFO] ✅ Poisson mesh already exists, skipping..."
    POISSON_SIZE=$(stat -c%s "$DENSE_DIR/meshed-poisson.ply" 2>/dev/null || echo "0")
    echo "[INFO] Existing Poisson mesh size: $POISSON_SIZE bytes"
else
    echo "[INFO] Creating Poisson mesh..."
    if colmap poisson_mesher \
        --input_path $WORKDIR/dense/${GEOREGIDIR}/fused.ply \
        --output_path $WORKDIR/dense/${GEOREGIDIR}/meshed-poisson.ply; then
        echo "[INFO] ✅ Poisson mesh created"
        POISSON_SIZE=$(stat -c%s "$DENSE_DIR/meshed-poisson.ply" 2>/dev/null || echo "0")
        echo "[INFO] Generated Poisson mesh size: $POISSON_SIZE bytes"
    else
        echo "[WARNING] ⚠️  Poisson mesh creation failed, trying Delaunay..."
    fi
fi

# Delaunay mesh
if [ "$FORCE_DENSE" = false ] && [ -f "$DENSE_DIR/meshed-delaunay.ply" ]; then
    echo "[INFO] ✅ Delaunay mesh already exists, skipping..."
    DELAUNAY_SIZE=$(stat -c%s "$DENSE_DIR/meshed-delaunay.ply" 2>/dev/null || echo "0")
    echo "[INFO] Existing Delaunay mesh size: $DELAUNAY_SIZE bytes"
else
    echo "[INFO] Creating Delaunay mesh..."
    if colmap delaunay_mesher \
        --input_path $WORKDIR/dense/${GEOREGIDIR} \
        --output_path $WORKDIR/dense/${GEOREGIDIR}/meshed-delaunay.ply; then
        echo "[INFO] ✅ Delaunay mesh created"
        DELAUNAY_SIZE=$(stat -c%s "$DENSE_DIR/meshed-delaunay.ply" 2>/dev/null || echo "0")
        echo "[INFO] Generated Delaunay mesh size: $DELAUNAY_SIZE bytes"
    else
        echo "[WARNING] ⚠️  Delaunay mesh creation failed"
    fi
fi

echo "[INFO] === DENSE RECONSTRUCTION COMPLETE ==="
echo "[INFO] Results in: $WORKDIR/dense/${GEOREGIDIR}/"
echo "[INFO] Point cloud: fused.ply"
echo "[INFO] Meshes: meshed-poisson.ply, meshed-delaunay.ply"

echo ""
echo "=== 🎉 PIPELINE COMPLETE - SUMMARY ==="
echo "✅ Dataset processed: $DATASETDIR"
echo "✅ Sparse reconstruction: $WORKDIR/sparse/0/"
echo "✅ Georegistered model: $WORKDIR/sparse/${GEOREGIDIR}/"
echo "✅ Dense reconstruction: $WORKDIR/dense/${GEOREGIDIR}/"
echo ""
echo "📁 Final outputs:"
if [ -f "$WORKDIR/dense/${GEOREGIDIR}/fused.ply" ]; then
    PLY_SIZE=$(stat -c%s "$WORKDIR/dense/${GEOREGIDIR}/fused.ply" 2>/dev/null | numfmt --to=iec)
    echo "  • Point cloud: fused.ply ($PLY_SIZE)"
fi
if [ -f "$WORKDIR/dense/${GEOREGIDIR}/meshed-poisson.ply" ]; then
    POISSON_SIZE=$(stat -c%s "$WORKDIR/dense/${GEOREGIDIR}/meshed-poisson.ply" 2>/dev/null | numfmt --to=iec)
    echo "  • Poisson mesh: meshed-poisson.ply ($POISSON_SIZE)"
fi
if [ -f "$WORKDIR/dense/${GEOREGIDIR}/meshed-delaunay.ply" ]; then
    DELAUNAY_SIZE=$(stat -c%s "$WORKDIR/dense/${GEOREGIDIR}/meshed-delaunay.ply" 2>/dev/null | numfmt --to=iec)
    echo "  • Delaunay mesh: meshed-delaunay.ply ($DELAUNAY_SIZE)"
fi
echo ""
echo "💡 Next steps:"
echo "   - Load PLY files in MeshLab, CloudCompare, or other 3D software"
echo "   - Use diagnostic script if there are issues: ./scripts/sensyn/diagnose_reconstruction.sh"
echo "   - Force re-run specific steps if needed: $0 $DATASETDIR --force-sparse/geo/dense"
