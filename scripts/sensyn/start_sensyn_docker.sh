#!/bin/sh
# This is a script for run all the stuff.
# Author: Masahiro Ogawa
###

SCRIPT=$(realpath $0)
TOPDIR=$(dirname $SCRIPT)/../..


# Check if custom colmap-sensyn image exists (fastest startup)
if docker image inspect colmap-sensyn:latest >/dev/null 2>&1; then
    echo "Using custom COLMAP-sensyn Docker image (pre-built with dependencies)..."
    COLMAP_IMAGE="colmap-sensyn:latest"
    SKIP_DEPS=true
# Check if local colmap:latest image exists (in case you ran build.sh)
elif docker image inspect colmap:latest >/dev/null 2>&1; then
    echo "Using local COLMAP Docker image..."
    COLMAP_IMAGE="colmap:latest"
    SKIP_DEPS=false
else
    echo "Local COLMAP image not found, pulling official image..."
    docker pull colmap/colmap:latest
    COLMAP_IMAGE="colmap/colmap:latest"
    SKIP_DEPS=false
fi

echo "[INFO] Starting COLMAP Docker container with interactive shell..."
echo "[INFO] You can run: ./scripts/sensyn/run_sfm.sh"
echo "[INFO] To exit, type 'exit' or press Ctrl+D"

# Start the container with or without GPU support
echo "Testing GPU access..."
if docker run --rm --runtime=nvidia $COLMAP_IMAGE find /usr/local/cuda-*/targets/*/lib -name "libcudart.so*" 2>/dev/null | head -1 >/dev/null 2>&1; then
    echo "✅ Using GPU acceleration with --runtime=nvidia"
    if [ "$SKIP_DEPS" = true ]; then
        docker run --runtime=nvidia -w /workspace -v "$TOPDIR":/workspace -it $COLMAP_IMAGE bash -c "
            echo '[INFO] GPU-enabled COLMAP container starting...'
            echo '[INFO] Using pre-built image with dependencies already installed'
            echo '[CUDA Info]: CUDA Runtime libraries found'
            echo '[INFO] Container ready. GPU acceleration enabled.'
            echo '[INFO] COLMAP Docker container ready. Run: ./scripts/sensyn/run_sfm.sh'
            exec bash
        "
    else
        docker run --runtime=nvidia -w /workspace -v "$TOPDIR":/workspace -it $COLMAP_IMAGE bash -c "
            echo '[INFO] GPU-enabled COLMAP container starting...'
            echo '[INFO] Installing required tools (python3, sqlite3, pandas)...'
            echo '[INFO] This may take a few minutes on first run...'
            apt-get update && apt-get install -y python3 python3-pip python3-pandas sqlite3
            echo '[INFO] Checking Python and SQLite installation...'
            if command -v python3 >/dev/null 2>&1; then
                echo '[INFO] ✅ Python3 installed successfully: \$(python3 --version)'
            else
                echo '[ERROR] ❌ Python3 installation failed - georegistration will not work'
            fi
            if command -v sqlite3 >/dev/null 2>&1; then
                echo '[INFO] ✅ sqlite3 installed successfully'
            else
                echo '[WARNING] ❌ sqlite3 installation failed - continuing without debugging tools'
            fi
            if python3 -c 'import pandas' >/dev/null 2>&1; then
                echo '[INFO] ✅ pandas installed successfully'
            else
                echo '[ERROR] ❌ pandas installation failed - poslog.csv processing will not work'
            fi
            echo '[CUDA Info]: CUDA Runtime libraries found'
            echo '[INFO] Container ready. GPU acceleration enabled.'
            echo '[INFO] COLMAP Docker container ready. Run: ./scripts/sensyn/run_sfm.sh'
            exec bash
        "
    fi
elif docker run --rm $COLMAP_IMAGE colmap --help >/dev/null 2>&1; then
    echo "⚠️  GPU not available, using CPU mode"
    if [ "$SKIP_DEPS" = true ]; then
        docker run -w /workspace -v "$TOPDIR":/workspace -it $COLMAP_IMAGE bash -c "
            echo '[INFO] CPU-only COLMAP container starting...'
            echo '[WARNING] GPU acceleration disabled. Dense reconstruction will be slower.'
            echo '[INFO] Using pre-built image with dependencies already installed'
            echo '[INFO] COLMAP Docker container ready. Run: ./scripts/sensyn/run_sfm.sh'
            exec bash
        "
    else
        docker run -w /workspace -v "$TOPDIR":/workspace -it $COLMAP_IMAGE bash -c "
            echo '[INFO] CPU-only COLMAP container starting...'
            echo '[WARNING] GPU acceleration disabled. Dense reconstruction will be slower.'
            echo '[INFO] Installing required tools (python3, sqlite3, pandas)...'
            echo '[INFO] This may take a few minutes on first run...'
            apt-get update && apt-get install -y python3 python3-pip python3-pandas sqlite3
            if command -v python3 >/dev/null 2>&1; then
                echo '[INFO] ✅ Python3 installed successfully: \$(python3 --version)'
            else
                echo '[ERROR] ❌ Python3 installation failed - georegistration will not work'
            fi
            if command -v sqlite3 >/dev/null 2>&1; then
                echo '[INFO] ✅ sqlite3 installed successfully'
            else
                echo '[WARNING] ❌ sqlite3 installation failed - continuing without debugging tools'
            fi
            if python3 -c 'import pandas' >/dev/null 2>&1; then
                echo '[INFO] ✅ pandas installed successfully'
            else
                echo '[ERROR] ❌ pandas installation failed - poslog.csv processing will not work'
            fi
            echo '[INFO] COLMAP Docker container ready. Run: ./scripts/sensyn/run_sfm.sh'
            exec bash
        "
    fi
else
    echo "⚠️  Container test failed, trying anyway in CPU mode"
    docker run -w /workspace -v "$TOPDIR":/workspace -it $COLMAP_IMAGE
fi

echo "[INFO] Exited Docker container"