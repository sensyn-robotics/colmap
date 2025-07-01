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