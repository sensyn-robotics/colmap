# Description
This is a readme to run all procedure of getting SfM result.

# Output
sfm result(meshed_poisson.ply) which is georegistered to ACSL's vslam camera positions.

# Setup
$ colmap/script/sensyn/build_sensyn.sh
This will start a colmap docker which mount the colmap top directory.

# Run
1. put input images into colmap/images
2. put ACSL.inc's camera position file "poslog.csv" into colmap/work
3. run below.
$ colmap/script/sensyn/run_sensyn.sh
