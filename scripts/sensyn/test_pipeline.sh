#!/bin/bash
# Simple test script to verify the pipeline logic without requiring colmap

echo "=== TESTING PIPELINE SKIP LOGIC ==="
echo "This simulates running the pipeline to test skip logic"
echo ""

DATASET="dataset"
echo "Dataset: $DATASET"
echo ""

# Test 1: Check if sparse reconstruction exists
echo "Test 1: Sparse reconstruction check"
if [ -d "${DATASET}/work/sparse/0" ] && [ -f "${DATASET}/work/sparse/0/cameras.bin" ] && [ -f "${DATASET}/work/sparse/0/images.bin" ] && [ -f "${DATASET}/work/sparse/0/points3D.bin" ]; then
    echo "✅ PASS: Sparse reconstruction detected (would skip)"
else
    echo "❌ FAIL: Sparse reconstruction missing (would run)"
fi

# Test 2: Check if campose.txt exists
echo ""
echo "Test 2: Camera pose file check"
if [ -f "${DATASET}/work/campose.txt" ]; then
    echo "✅ PASS: Camera pose file detected (would skip conversion)"
else
    echo "❌ FAIL: Camera pose file missing (would run conversion)"
fi

# Test 3: Check if georegistration exists
echo ""
echo "Test 3: Georegistration check"
GEOREGIDIR="georegistration"
if [ -f "${DATASET}/work/sparse/${GEOREGIDIR}/cameras.bin" ] && [ -f "${DATASET}/work/sparse/${GEOREGIDIR}/images.bin" ] && [ -f "${DATASET}/work/sparse/${GEOREGIDIR}/points3D.bin" ]; then
    echo "✅ PASS: Georegistration detected (would skip)"
else
    echo "❌ FAIL: Georegistration missing (would run)"
fi

# Test 4: Check if dense reconstruction exists
echo ""
echo "Test 4: Dense reconstruction check"
DENSE_DIR="${DATASET}/work/dense/${GEOREGIDIR}"
if [ -f "$DENSE_DIR/fused.ply" ] && ([ -f "$DENSE_DIR/meshed-poisson.ply" ] || [ -f "$DENSE_DIR/meshed-delaunay.ply" ]); then
    echo "✅ PASS: Dense reconstruction detected (would skip)"
else
    echo "❌ FAIL: Dense reconstruction missing (would run)"
fi

# Test 5: Check metadata type detection
echo ""
echo "Test 5: Metadata type detection"
if [ -f "${DATASET}/poslog.csv" ]; then
    echo "✅ ACSL poslog.csv detected -> ref_is_gps=1"
elif [ -f "${DATASET}/metadata.json" ]; then
    echo "✅ Record3D metadata.json detected -> ref_is_gps=0"
else
    echo "❌ No metadata file detected"
fi

echo ""
echo "=== SKIP LOGIC TEST COMPLETE ==="
