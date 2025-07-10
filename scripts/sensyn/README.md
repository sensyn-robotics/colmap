# Description
This is a readme to run all procedure of getting SfM result.

# Output
sfm result(meshed_poisson.ply) which is georegistered to ACSL's vslam camera positions in colmap/dataset/work.

# Setup
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

# Run
1. put input images into colmap/dataset/images
2. put posefile into colmap/dataset. current supported format is
  - ACSL.inc's camera position file "poslog.csv" 
  - iPhone app Record3D's "metadata.json".
3. run below.
```
./scripts/sensyn/run_sfm.sh
```
