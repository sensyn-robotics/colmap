#!/bin/bash
# One-command Docker pipeline runner
# Usage: ./run_pipeline_docker.sh <dataset_path> [options]

USAGE="Usage: $0 <dataset_path> [options]

Runs the COLMAP SfM pipeline in Docker with automatic setup.

Examples:
  $0 ./dataset                    # Run full pipeline
  $0 ./dataset --force-sparse     # Force re-run sparse reconstruction
  $0 ./dataset --force-dense      # Force re-run dense reconstruction
  $0 ./dataset --help             # Show pipeline help

Options are passed directly to the pipeline script.

Requirements:
  - Dataset must contain images/ directory
  - Dataset must contain poslog.csv or metadata.json
  - Docker must be installed and running
"

if [ $# -lt 1 ]; then
    echo "$USAGE"
    exit 1
fi

DATASET_PATH="$1"
shift # Remove dataset path, keep other arguments

# Check if dataset exists
if [ ! -d "$DATASET_PATH" ]; then
    echo "[ERROR] Dataset directory not found: $DATASET_PATH"
    exit 1
fi

# Check if dataset has required structure
if [ ! -d "$DATASET_PATH/images" ]; then
    echo "[ERROR] No images/ directory found in $DATASET_PATH"
    echo "[ERROR] Dataset must contain an images/ directory with photos"
    exit 1
fi

if [ ! -f "$DATASET_PATH/poslog.csv" ] && [ ! -f "$DATASET_PATH/metadata.json" ]; then
    echo "[ERROR] No poslog.csv or metadata.json found in $DATASET_PATH"
    echo "[ERROR] Dataset must contain camera position data"
    exit 1
fi

# Get absolute path to dataset
DATASET_ABS=$(realpath "$DATASET_PATH")
COLMAP_ROOT=$(dirname $(realpath $0))/../..

echo "=== 🐳 COLMAP DOCKER PIPELINE ==="
echo "Dataset: $DATASET_ABS"
echo "Pipeline arguments: $@"
echo ""

# Check for custom image first
if docker image inspect colmap-sensyn:latest >/dev/null 2>&1; then
    echo "[INFO] Using custom COLMAP-sensyn image (fastest startup)"
    DOCKER_IMAGE="colmap-sensyn:latest"
    INSTALL_DEPS=""
elif docker image inspect colmap:latest >/dev/null 2>&1; then
    echo "[INFO] Using local COLMAP image, will install dependencies"
    DOCKER_IMAGE="colmap:latest"
    INSTALL_DEPS="apt-get update && apt-get install -y python3 python3-pandas sqlite3 && "
else
    echo "[INFO] Pulling official COLMAP image..."
    docker pull colmap/colmap:latest
    DOCKER_IMAGE="colmap/colmap:latest"
    INSTALL_DEPS="apt-get update && apt-get install -y python3 python3-pandas sqlite3 && "
fi

# Prepare Docker run command
DOCKER_ARGS=""

# Try GPU first, fallback to CPU
if docker run --rm --gpus all $DOCKER_IMAGE nvidia-smi >/dev/null 2>&1; then
    echo "[INFO] 🚀 GPU detected, using CUDA acceleration"
    DOCKER_ARGS="--gpus all"
else
    echo "[INFO] 💻 GPU not available, using CPU mode"
    echo "[WARNING] Dense reconstruction will be slower without GPU"
fi

# Run the pipeline
echo "[INFO] Starting COLMAP pipeline in Docker..."
echo "[INFO] This may take several minutes to hours depending on dataset size"
echo ""

docker run --rm $DOCKER_ARGS \
    -v "$COLMAP_ROOT":/workspace \
    -v "$DATASET_ABS":/workspace/current_dataset \
    -w /workspace \
    $DOCKER_IMAGE \
    bash -c "
        echo '[INFO] 🐳 Docker container started'
        $INSTALL_DEPS
        echo '[INFO] Running pipeline: ./scripts/sensyn/create_georegistered_mesh.sh current_dataset $@'
        ./scripts/sensyn/create_georegistered_mesh.sh current_dataset $@
        echo '[INFO] Pipeline complete. Results saved to: $DATASET_ABS/work/'
    "

echo ""
echo "=== 🏁 DOCKER PIPELINE COMPLETE ==="
echo "Results saved to: $DATASET_ABS/work/"
echo ""
echo "💡 To view results:"
echo "   - Point cloud: $DATASET_ABS/work/dense/georegistration/fused.ply"
echo "   - Meshes: $DATASET_ABS/work/dense/georegistration/meshed-*.ply"
echo "   - Load in MeshLab, CloudCompare, or other 3D software"
