#!/bin/bash
# Test script for skip logic functionality
# This script tests the various skip modes in create_georegistered_mesh.sh

echo "=== Testing COLMAP Skip Logic ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DATASET="/home/mas/proj/sensyn/colmap/dataset"

if [ ! -d "$TEST_DATASET" ]; then
    echo "❌ Test dataset not found: $TEST_DATASET"
    echo "Please ensure you have a dataset with images/ folder"
    exit 1
fi

echo "📁 Using test dataset: $TEST_DATASET"
echo ""

echo "=== Test 1: Help message ==="
echo "🧪 Testing --help option"
$SCRIPT_DIR/create_georegistered_mesh.sh --help
echo ""

echo "=== Test 2: Smart mode (default) ==="
echo "🧪 Testing default behavior (smart skip)"
echo "This should skip any existing results automatically..."
echo "Command: $SCRIPT_DIR/create_georegistered_mesh.sh $TEST_DATASET"
echo ""
echo "Run the following command manually to test:"
echo "$SCRIPT_DIR/create_georegistered_mesh.sh $TEST_DATASET"
echo ""

echo "=== Test 3: Force modes ==="
echo "🧪 These commands would force re-run different parts:"
echo ""
echo "Force all steps:"
echo "$SCRIPT_DIR/create_georegistered_mesh.sh $TEST_DATASET --force-all"
echo ""
echo "Force only sparse reconstruction:"
echo "$SCRIPT_DIR/create_georegistered_mesh.sh $TEST_DATASET --force-sparse"
echo ""
echo "Force only georegistration:"
echo "$SCRIPT_DIR/create_georegistered_mesh.sh $TEST_DATASET --force-geo"
echo ""
echo "Force only dense reconstruction:"
echo "$SCRIPT_DIR/create_georegistered_mesh.sh $TEST_DATASET --force-dense"
echo ""

echo "=== Test 4: Check existing results ==="
WORK_DIR="$TEST_DATASET/work"
if [ -d "$WORK_DIR" ]; then
    echo "📊 Current results in $WORK_DIR:"
    echo ""
    
    echo "Sparse reconstruction:"
    if [ -f "$WORK_DIR/sparse/0/cameras.bin" ]; then
        echo "  ✅ Sparse reconstruction exists"
        echo "     Files: $(ls -la $WORK_DIR/sparse/0/ | grep -E '\.(bin|txt)$' | wc -l) files"
    else
        echo "  ❌ Sparse reconstruction missing"
    fi
    
    echo "Camera poses:"
    if [ -f "$WORK_DIR/campose.txt" ]; then
        echo "  ✅ Camera poses exist ($(wc -l < $WORK_DIR/campose.txt) lines)"
    else
        echo "  ❌ Camera poses missing"
    fi
    
    echo "Georegistration:"
    if [ -f "$WORK_DIR/sparse/georegistration/cameras.bin" ]; then
        echo "  ✅ Georegistration exists"
    else
        echo "  ❌ Georegistration missing"
    fi
    
    echo "Dense reconstruction:"
    DENSE_DIR="$WORK_DIR/dense/georegistration"
    if [ -f "$DENSE_DIR/fused.ply" ]; then
        PLY_SIZE=$(stat -c%s "$DENSE_DIR/fused.ply" 2>/dev/null || echo "0")
        echo "  ✅ Point cloud exists ($PLY_SIZE bytes)"
    else
        echo "  ❌ Point cloud missing"
    fi
    
    if [ -f "$DENSE_DIR/meshed-poisson.ply" ]; then
        MESH_SIZE=$(stat -c%s "$DENSE_DIR/meshed-poisson.ply" 2>/dev/null || echo "0")
        echo "  ✅ Poisson mesh exists ($MESH_SIZE bytes)"
    else
        echo "  ❌ Poisson mesh missing"
    fi
    
    if [ -f "$DENSE_DIR/meshed-delaunay.ply" ]; then
        MESH_SIZE=$(stat -c%s "$DENSE_DIR/meshed-delaunay.ply" 2>/dev/null || echo "0")
        echo "  ✅ Delaunay mesh exists ($MESH_SIZE bytes)"
    else
        echo "  ❌ Delaunay mesh missing"
    fi
else
    echo "❌ No work directory found - no previous results"
fi

echo ""
echo "=== Skip Logic Test Complete ==="
echo ""
echo "💡 Usage recommendations:"
echo "1. Run normally first: ./create_georegistered_mesh.sh $TEST_DATASET"
echo "2. Run again to see skip behavior"
echo "3. Use --force-* options to re-run specific parts"
echo "4. Use --help for complete usage information"
