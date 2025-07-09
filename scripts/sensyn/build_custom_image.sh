#!/bin/bash
# Build a custom COLMAP Docker image with pre-installed Python dependencies
# This will speed up container startup by avoiding repeated package installation

echo "[INFO] Building custom COLMAP image with Python dependencies..."

# Create a temporary Dockerfile
cat > /tmp/Dockerfile.colmap-sensyn << 'EOF'
FROM colmap/colmap:latest

# Install Python dependencies once during build
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-pandas \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Default command
CMD ["bash"]
EOF

# Build the custom image
docker build -t colmap-sensyn:latest -f /tmp/Dockerfile.colmap-sensyn /tmp/

if [ $? -eq 0 ]; then
    echo "[INFO] ✅ Custom COLMAP image built successfully!"
    echo "[INFO] Image name: colmap-sensyn:latest"
    echo "[INFO] You can now update start_sensyn_docker.sh to use this image"
else
    echo "[ERROR] ❌ Failed to build custom image"
    exit 1
fi

# Clean up
rm -f /tmp/Dockerfile.colmap-sensyn

echo "[INFO] To use this image, modify start_sensyn_docker.sh to use 'colmap-sensyn:latest'"
