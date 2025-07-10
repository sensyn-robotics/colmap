# Description
This is a readme to run all procedure of getting SfM result.

# Output
sfm result(meshed_poisson.ply) which is georegistered to ACSL's vslam camera positions in colmap/dataset/work.

# Setup

## Method 1: Docker (Recommended)
Docker provides a consistent environment and handles all dependencies automatically.

### Quick Start
```bash
# 1. Build optimized Docker image (one-time setup, ~5-10 minutes)
./scripts/sensyn/docker_manager.sh build

# 2. Run pipeline on your dataset
./scripts/sensyn/docker_manager.sh run /path/to/your/dataset

# 3. View results in your dataset/work/ directory
```

### Docker Management
```bash
# Check Docker setup status
./scripts/sensyn/docker_manager.sh status

# Interactive Docker shell for debugging
./scripts/sensyn/docker_manager.sh shell

# Clean up Docker images
./scripts/sensyn/docker_manager.sh clean

# Show all available commands
./scripts/sensyn/docker_manager.sh help
```

### Alternative Docker Commands
```bash
# One-command pipeline execution
./scripts/sensyn/run_pipeline_docker.sh /path/to/dataset

# With force options
./scripts/sensyn/run_pipeline_docker.sh /path/to/dataset --force-dense

# Manual Docker shell (slower startup)
./scripts/sensyn/start_sensyn_docker.sh
```

## Method 2: Manual Setup (Advanced)
### Build Custom Image 
```bash
# Build custom image with dependencies pre-installed (one-time setup)
./scripts/sensyn/build_custom_image.sh

# This creates 'colmap-sensyn:latest' with python3, sqlite3, and pandas pre-installed
# Container startup will be < 30 seconds after this
```

### Start docker
```bash
# Current version installs dependencies on each startup (5+ minutes)
./scripts/sensyn/start_sensyn_docker.sh
```
This will start a colmap docker which mount the colmap top directory.

# Usage

## Dataset Requirements
Your dataset directory must contain:
- `images/` directory with photos (.jpg, .png, .jpeg)
- Camera position data:
  - `poslog.csv` (ACSL format with GPS coordinates)
  - OR `metadata.json` (Record3D format with local coordinates)

## Running the Pipeline

### Method 1: Docker (Recommended)
```bash
# Quick run with auto-setup
./scripts/sensyn/docker_manager.sh run /path/to/dataset

# Or direct command
./scripts/sensyn/run_pipeline_docker.sh /path/to/dataset
```

### Method 2: Manual (inside Docker shell)
1. put input images into colmap/dataset/images
2. put posefile into colmap/dataset. current supported format is
  - ACSL.inc's camera position file "poslog.csv" 
  - iPhone app Record3D's "metadata.json".
3. run below.
```
./scripts/sensyn/run_sfm.sh
```

## Pipeline Options
The pipeline automatically skips completed steps for efficiency:

```bash
# View all options
./scripts/sensyn/docker_manager.sh run dataset --help

# Force re-run specific steps
./scripts/sensyn/docker_manager.sh run dataset --force-sparse   # Re-run feature extraction and matching
./scripts/sensyn/docker_manager.sh run dataset --force-geo      # Re-run georegistration  
./scripts/sensyn/docker_manager.sh run dataset --force-dense    # Re-run dense reconstruction
./scripts/sensyn/docker_manager.sh run dataset --force-all      # Re-run everything
```

## Troubleshooting

### Common Issues

#### CUDA Driver Mismatch (most common)
If you see: `CUDA driver version is insufficient for CUDA runtime version`

**Quick Fix:**
```bash
# Use CPU mode to avoid CUDA issues entirely
./scripts/sensyn/docker_manager.sh run dataset --cpu-only
```

#### CUDA PTX Toolchain Mismatch
If you see: `the provided PTX was compiled with an unsupported toolchain`

**Quick Fix:**
```bash
# Use CPU mode for dense reconstruction only (other steps use GPU)
./scripts/sensyn/docker_manager.sh run dataset --cpu-dense
```

**Diagnostic:**
```bash
# Check your CUDA setup
./scripts/sensyn/check_cuda.sh
```

#### Performance Issues
```bash
# For slower CPU processing, reduce image size
./scripts/sensyn/docker_manager.sh run dataset --cpu-only --force-dense

# Inside the container, manually set smaller image size:
colmap patch_match_stereo --PatchMatchStereo.max_image_size 600
```

#### General Troubleshooting
```bash
# Check pipeline health
./scripts/sensyn/diagnose_reconstruction.sh /path/to/dataset

# Check Docker setup
./scripts/sensyn/docker_manager.sh status

# Interactive debugging
./scripts/sensyn/docker_manager.sh shell

# CUDA compatibility check
./scripts/sensyn/check_cuda.sh
```
