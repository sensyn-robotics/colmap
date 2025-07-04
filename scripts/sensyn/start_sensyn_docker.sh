#!/bin/sh
# This is a script for run all the stuff for ACSL.inc's data.
# Author: Masahiro Ogawa
###

SCRIPT=$(realpath $0)
TOPDIR=$(dirname $SCRIPT)/../..

# Check if local colmap:latest image exists (in case you ran build.sh), otherwise use official image
if docker image inspect colmap:latest >/dev/null 2>&1; then
    echo "Using local COLMAP Docker image..."
    COLMAP_IMAGE="colmap:latest"
else
    echo "Local COLMAP image not found, pulling official image..."
    docker pull colmap/colmap:latest
    COLMAP_IMAGE="colmap/colmap:latest"
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
    $COLMAP_IMAGE \
     bash -c "
        echo '[INFO] COLMAP Docker container starting...'
        echo '[INFO] Installing debugging tools (sqlite3)...'
        apt-get update >/dev/null 2>&1 && apt-get install -y sqlite3 >/dev/null 2>&1
        if command -v sqlite3 >/dev/null 2>&1; then
            echo '[INFO] ✅ sqlite3 installed successfully'
        else
            echo '[WARNING] ❌ sqlite3 installation failed - continuing without debugging tools'
        fi
        echo '[INFO] COLMAP Docker container ready. Run: ./scripts/sensyn/run_sfm.sh'
        exec bash
    "

echo "[INFO] Exited Docker container"