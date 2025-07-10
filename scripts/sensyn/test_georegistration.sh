#!/bin/bash
# Quick test script for georegistration only
# Usage: ./test_georegistration.sh <dataset_dir>

if [ $# -lt 1 ]; then
    echo "Usage: $0 <dataset_directory>"
    echo "Example: $0 dataset/"
    exit 1
fi

DATASETDIR=$1
WORKDIR=${DATASETDIR}/work

echo "=== TESTING GEOREGISTRATION ==="
echo "Dataset: $DATASETDIR"

# Check prerequisites
if [ ! -d "$WORKDIR/sparse/0" ]; then
    echo "❌ ERROR: No sparse reconstruction found"
    echo "   Run the full pipeline first to create sparse reconstruction"
    exit 1
fi

if [ ! -f "$WORKDIR/campose.txt" ]; then
    echo "❌ ERROR: No campose.txt found"
    echo "   Run the metadata conversion step first"
    exit 1
fi

# Determine coordinate system
if [ -f "${DATASETDIR}/poslog.csv" ]; then
    echo "📍 Using GPS coordinates from poslog.csv"
    REF_IS_GPS=1
elif [ -f "${DATASETDIR}/metadata.json" ]; then
    echo "📍 Using local coordinates from Record3D metadata.json"
    REF_IS_GPS=0
else
    echo "❌ ERROR: No metadata source found"
    exit 1
fi

# Clean up any previous test
rm -rf "$WORKDIR/sparse/test_georegistration"
mkdir -p "$WORKDIR/sparse/test_georegistration"

echo "🔧 Testing georegistration (ref_is_gps=$REF_IS_GPS)..."

# Run georegistration test
if colmap model_aligner \
    --input_path ${WORKDIR}/sparse/0 \
    --output_path ${WORKDIR}/sparse/test_georegistration \
    --ref_images_path ${WORKDIR}/campose.txt \
    --ref_is_gps $REF_IS_GPS \
    --alignment_max_error 5.0; then
    
    echo "✅ Georegistration test SUCCESSFUL!"
    
    # Check output files
    FILES=$(find "$WORKDIR/sparse/test_georegistration" -name "*.bin" | wc -l)
    echo "   Created $FILES binary files"
    
    if [ $FILES -gt 0 ]; then
        echo "   ✅ cameras.bin: $([ -f "$WORKDIR/sparse/test_georegistration/cameras.bin" ] && echo "exists" || echo "missing")"
        echo "   ✅ images.bin: $([ -f "$WORKDIR/sparse/test_georegistration/images.bin" ] && echo "exists" || echo "missing")"
        echo "   ✅ points3D.bin: $([ -f "$WORKDIR/sparse/test_georegistration/points3D.bin" ] && echo "exists" || echo "missing")"
        echo ""
        echo "🎉 Georegistration is working correctly!"
        echo "   You can now run the full pipeline without issues."
    else
        echo "❌ No output files created"
    fi
else
    echo "❌ Georegistration test FAILED!"
    echo "   Try adjusting parameters or check coordinate system"
fi

# Clean up test directory
rm -rf "$WORKDIR/sparse/test_georegistration"
echo "=== TEST COMPLETE ==="
