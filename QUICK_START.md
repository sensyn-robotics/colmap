# COLMAP Docker Setup - Quick Start Guide

## Problem: Slow Container Startup
The container takes 5+ minutes to start because it installs `python3`, `sqlite3`, and `pandas` every time.

**UPDATE**: Fixed! The build script now uses `python3-pandas` from Ubuntu repos instead of pip to avoid PEP 668 restrictions.

## Solution: Pre-built Custom Image

### Option 1: Build Custom Image (Recommended - Fast Startup)
```bash
# Build custom image with dependencies pre-installed (one-time setup)
./scripts/sensyn/build_custom_image.sh

# This creates 'colmap-sensyn:latest' with python3, sqlite3, and pandas pre-installed
# Container startup will be < 30 seconds after this
```

### Option 2: Use Current Version (Slow but Works)
```bash
# Current version installs dependencies on each startup (5+ minutes)
./scripts/sensyn/start_sensyn_docker.sh
```

## How It Works

The updated `start_sensyn_docker.sh` script now:

1. **Checks for custom image first**: `colmap-sensyn:latest` 
   - If found: Quick startup (< 30 seconds)
   - Dependencies already installed
   
2. **Falls back to local image**: `colmap:latest`
   - If found: Installs dependencies (2-5 minutes)
   - Shows installation progress
   
3. **Falls back to official image**: `colmap/colmap:latest`
   - Downloads if needed, then installs dependencies (5+ minutes)
   - Shows installation progress

## Quick Setup Commands

```bash
# 1. Build custom image (one-time, takes 3-5 minutes)
./scripts/sensyn/build_custom_image.sh

# 2. Start container (fast with custom image)
./scripts/sensyn/start_sensyn_docker.sh

# 3. Run georegistration pipeline
./scripts/sensyn/run_sfm.sh
```

## What's Installed

- **python3**: For georegistration scripts
- **sqlite3**: For database debugging  
- **python3-pandas**: For poslog.csv processing (Ubuntu package, not pip)
- **Standard libraries**: json, os, sys (for Record3D metadata)

## Success! 

✅ **Custom image built successfully**: `colmap-sensyn:latest`
✅ **Fast startup**: Container now starts in < 30 seconds
✅ **Dependencies pre-installed**: python3, sqlite3, pandas ready to use

## Troubleshooting

If container startup is still slow:
1. Check internet connection
2. Try: `docker system prune` to clean up old containers
3. Build custom image: `./scripts/sensyn/build_custom_image.sh`
