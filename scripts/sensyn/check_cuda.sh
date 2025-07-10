#!/bin/bash
# CUDA Compatibility Diagnostic Script

echo "=== 🔧 CUDA COMPATIBILITY DIAGNOSTIC ==="
echo ""

# Check if Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not installed"
    exit 1
fi

echo "✅ Docker is available"

# Check if nvidia-docker is available
if docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi >/dev/null 2>&1; then
    echo "✅ NVIDIA Docker runtime is working"
    
    # Check CUDA driver version
    echo ""
    echo "=== HOST CUDA DRIVER INFO ==="
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=driver_version,cuda_version --format=csv,noheader,nounits | head -1
    else
        echo "❌ nvidia-smi not available on host"
    fi
    
    echo ""
    echo "=== CONTAINER CUDA RUNTIME INFO ==="
    docker run --rm --gpus all colmap/colmap:latest bash -c "
        echo 'CUDA Runtime Version:' 
        nvcc --version 2>/dev/null | grep 'release' || echo 'nvcc not available'
        echo 'GPU Status:'
        nvidia-smi --query-gpu=name,driver_version,cuda_version --format=csv,noheader 2>/dev/null || echo 'nvidia-smi failed in container'
    "
    
    echo ""
    echo "=== COMPATIBILITY TEST ==="
    if docker run --rm --gpus all colmap/colmap:latest colmap patch_match_stereo --help >/dev/null 2>&1; then
        echo "✅ COLMAP GPU commands work in container"
        echo ""
        echo "💡 RECOMMENDATION: Use GPU mode"
        echo "   Command: ./scripts/sensyn/docker_manager.sh run dataset"
    else
        echo "❌ COLMAP GPU commands fail in container"
        echo ""
        echo "💡 RECOMMENDATION: Use CPU mode"
        echo "   Command: ./scripts/sensyn/docker_manager.sh run dataset --cpu-only"
    fi
    
else
    echo "❌ NVIDIA Docker runtime not working"
    echo ""
    echo "Possible issues:"
    echo "1. No NVIDIA GPU available"
    echo "2. NVIDIA Docker runtime not installed"
    echo "3. CUDA driver version mismatch"
    echo ""
    echo "💡 RECOMMENDATION: Use CPU mode"
    echo "   Command: ./scripts/sensyn/docker_manager.sh run dataset --cpu-only"
fi

echo ""
echo "=== QUICK FIXES ==="
echo ""
echo "🔧 For CUDA driver mismatch errors:"
echo "   Use: --cpu-only flag to avoid GPU entirely"
echo ""
echo "🔧 For slow CPU performance:"
echo "   - Reduce image count in dataset"
echo "   - Use smaller --max_image_size (600-800)"
echo "   - Process dataset in smaller batches"
echo ""
echo "🔧 For installation issues:"
echo "   sudo apt install nvidia-docker2 && sudo systemctl restart docker"
