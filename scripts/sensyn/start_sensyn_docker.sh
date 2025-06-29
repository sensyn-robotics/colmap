#!/bin/sh
# This is a script for run all the stuff for ACSL.inc's data.
# Author: Masahiro Ogawa
###

SCRIPT=$(realpath $0)
TOPDIR=$(dirname $SCRIPT)/../..

echo "[INFO] Pulling official COLMAP Docker image..."
docker pull colmap/colmap:latest

if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to pull COLMAP Docker image"
    exit 1
fi

echo "[INFO] Starting COLMAP Docker container with interactive shell..."
echo "[INFO] You can run: ./scripts/sensyn/run_sfm.sh"
echo "[INFO] To exit, type 'exit' or press Ctrl+D"

# Start the container with or without GPU support
docker run \
    --runtime=nvidia \
    -it \
    --rm \
    -v "${TOPDIR}":/workspace \
    -w /workspace \
    colmap/colmap:latest \
    bash -c "echo 'COLMAP Docker container ready. Run: ./scripts/sensyn/run_sfm.sh'; exec bash"

echo "[INFO] Exited Docker container"