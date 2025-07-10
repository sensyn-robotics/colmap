#!/bin/bash
# Build a custom COLMAP Docker image with pre-installed Python dependencies
# This will speed up container startup by avoiding repeated package installation

echo "[INFO] Building custom COLMAP image with Python dependencies..."
echo "[INFO] Using CUDA 12.9.1 (matching tested configuration)"

# Get the script directory to find our Dockerfile
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_PATH="$SCRIPT_DIR/Dockerfile"

if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "[ERROR] Dockerfile not found at: $DOCKERFILE_PATH"
    exit 1
fi

echo "[INFO] Building from: $DOCKERFILE_PATH"

# Build the custom image
docker build -t colmap-sensyn:latest -f "$DOCKERFILE_PATH" "$SCRIPT_DIR"

if [ $? -eq 0 ]; then
    echo "[INFO] ✅ Custom COLMAP image built successfully!"
    echo "[INFO] Image name: colmap-sensyn:latest"
    echo "[INFO] Built with CUDA 12.9.1 from source (tested configuration)"
    echo "[INFO] Image includes: COLMAP, Python3, pandas, numpy, sqlite3, imagemagick, jq"
else
    echo "[ERROR] ❌ Failed to build custom image"
    exit 1
fi

echo "[INFO] To use this image, run: ./scripts/sensyn/docker_manager.sh shell"
echo "[INFO] Or run pipeline with: ./scripts/sensyn/docker_manager.sh run <dataset_path>"
