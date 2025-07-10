#!/bin/bash
# Build a custom COLMAP Docker image with pre-installed Python dependencies
# This will speed up container startup by avoiding repeated package installation

echo "[INFO] Building custom COLMAP image with Python dependencies..."

# Create a temporary Dockerfile
cat > /tmp/Dockerfile.colmap-sensyn << 'EOF'
FROM colmap/colmap:latest

# Install Python dependencies and useful tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-pandas \
    python3-numpy \
    sqlite3 \
    curl \
    wget \
    vim \
    nano \
    htop \
    tree \
    git \
    && rm -rf /var/lib/apt/lists/*

# Verify installations work
RUN python3 --version && \
    python3 -c "import pandas; import numpy; print('✅ Python packages installed')" && \
    sqlite3 --version && \
    colmap --help | head -5

# Set working directory
WORKDIR /workspace

# Add helpful aliases and environment
RUN echo 'alias ll="ls -la"' >> /root/.bashrc && \
    echo 'alias colmap-version="colmap --version"' >> /root/.bashrc && \
    echo 'alias check-gpu="nvidia-smi 2>/dev/null || echo \"No GPU detected\""' >> /root/.bashrc && \
    echo 'echo "🐳 COLMAP-Sensyn Docker Container Ready!"' >> /root/.bashrc && \
    echo 'echo "📁 Workspace: /workspace"' >> /root/.bashrc && \
    echo 'echo "🚀 Run: ./scripts/sensyn/run_sfm.sh to start pipeline"' >> /root/.bashrc && \
    echo 'echo "💡 Available commands: colmap, python3, sqlite3"' >> /root/.bashrc

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
