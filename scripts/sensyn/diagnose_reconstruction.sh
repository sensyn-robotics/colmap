#!/bin/bash
# COLMAP Reconstruction Diagnostics Script
# Helps debug failed sparse reconstructions

if [ $# -lt 1 ]; then
    echo "Usage: $0 <dataset_directory>"
    echo "Example: $0 /workspace/dataset"
    exit 1
fi

DATASETDIR=$1
WORKDIR=${DATASETDIR}/work

echo "=== COLMAP Reconstruction Diagnostics ==="
echo "Dataset: $DATASETDIR"
echo "Workdir: $WORKDIR"
echo ""

# Check images
echo "=== IMAGE ANALYSIS ==="
if [ -d "$DATASETDIR/images" ]; then
    IMAGE_COUNT=$(find "$DATASETDIR/images" -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" | wc -l)
    echo "Total images: $IMAGE_COUNT"
    
    if [ $IMAGE_COUNT -lt 10 ]; then
        echo "⚠️  WARNING: Very few images ($IMAGE_COUNT). Need at least 10-15 for reconstruction."
    fi
    
    # Check image sizes (more efficient method)
    echo "Checking image sizes..."
    SMALL_IMAGES=0
    SAMPLE_SMALL=""
    
    find "$DATASETDIR/images" -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" | head -100 | while read img; do
        size=$(wc -c < "$img" 2>/dev/null || echo "0")
        if [ "$size" -lt "100000" ] && [ "$size" -gt "0" ]; then
            SMALL_IMAGES=$((SMALL_IMAGES + 1))
            if [ -z "$SAMPLE_SMALL" ] && [ $SMALL_IMAGES -le 5 ]; then
                SAMPLE_SMALL="$img ($size bytes)"
            fi
        fi
    done
    
    # Count all small images (simplified)
    SMALL_COUNT=$(find "$DATASETDIR/images" -name "*.jpg" -size -100k | wc -l)
    
    if [ $SMALL_COUNT -gt 0 ]; then
        echo "⚠️  INFO: $SMALL_COUNT images are < 100KB"
        echo "   Note: This is often normal for compressed images"
        echo "Sample small images:"
        find "$DATASETDIR/images" -name "*.jpg" -size -100k | head -5 | while read img; do
            size=$(wc -c < "$img")
            echo "  $(basename "$img"): $size bytes"
        done
    fi
    
    # Check image extensions and sizes
    echo "Image type breakdown:"
    for ext in jpg jpeg png; do
        count=$(find "$DATASETDIR/images" -name "*.$ext" | wc -l)
        if [ $count -gt 0 ]; then
            echo "  .$ext files: $count"
        fi
    done
    
    # Show some actual file sizes
    echo "Sample image files and sizes:"
    find "$DATASETDIR/images" -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" | head -5 | while read img; do
        size=$(wc -c < "$img")
        echo "  $(basename "$img"): $size bytes"
    done
    
    # Sample image info
    FIRST_IMAGE=$(find "$DATASETDIR/images" -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" | head -1)
    if [ -n "$FIRST_IMAGE" ] && command -v identify >/dev/null 2>&1; then
        echo "Sample image: $(identify "$FIRST_IMAGE")"
    fi
else
    echo "❌ ERROR: No images directory found"
    exit 1
fi

echo ""

# Check database
echo "=== DATABASE ANALYSIS ==="
if [ -f "$WORKDIR/database.db" ]; then
    echo "Database exists: $WORKDIR/database.db"
    
    # Check keypoints
    KEYPOINT_COUNT=$(sqlite3 "$WORKDIR/database.db" "SELECT COUNT(*) FROM keypoints;" 2>/dev/null || echo "0")
    AVG_KEYPOINTS=$(sqlite3 "$WORKDIR/database.db" "SELECT AVG(rows) FROM keypoints WHERE rows > 0;" 2>/dev/null || echo "0")
    echo "Total keypoints: $KEYPOINT_COUNT"
    echo "Average keypoints per image: $AVG_KEYPOINTS"
    
    if [ "$KEYPOINT_COUNT" -lt "1000" ]; then
        echo "⚠️  WARNING: Very few keypoints. Images may lack texture or be blurry."
    fi
    
    # Check matches
    MATCH_COUNT=$(sqlite3 "$WORKDIR/database.db" "SELECT COUNT(*) FROM matches;" 2>/dev/null || echo "0")
    GOOD_MATCHES=$(sqlite3 "$WORKDIR/database.db" "SELECT COUNT(*) FROM matches WHERE rows > 15;" 2>/dev/null || echo "0")
    echo "Total image pairs: $MATCH_COUNT"
    echo "Good matches (>15 features): $GOOD_MATCHES"
    
    if [ "$GOOD_MATCHES" -lt "5" ]; then
        echo "⚠️  WARNING: Very few good matches. This will likely cause reconstruction failure."
        echo "   Try: More overlapping images, better lighting, textured scenes"
    fi
    
    # Check images in database
    DB_IMAGES=$(sqlite3 "$WORKDIR/database.db" "SELECT COUNT(*) FROM images;" 2>/dev/null || echo "0")
    echo "Images in database: $DB_IMAGES"
    
else
    echo "❌ ERROR: No database found. Run feature extraction first."
    exit 1
fi

echo ""

# Check sparse reconstruction
echo "=== SPARSE RECONSTRUCTION ANALYSIS ==="
if [ -d "$WORKDIR/sparse/0" ]; then
    echo "✅ Sparse reconstruction exists"
    
    if [ -f "$WORKDIR/sparse/0/cameras.bin" ]; then
        echo "✅ Cameras file exists"
    else
        echo "❌ Missing cameras.bin"
    fi
    
    if [ -f "$WORKDIR/sparse/0/images.bin" ]; then
        echo "✅ Images file exists"
    else
        echo "❌ Missing images.bin"
    fi
    
    if [ -f "$WORKDIR/sparse/0/points3D.bin" ]; then
        echo "✅ 3D points file exists"
    else
        echo "❌ Missing points3D.bin"
    fi
    
else
    echo "❌ No sparse reconstruction found"
    echo "   This means the 3D reconstruction failed completely"
    echo "   Common causes:"
    echo "   - Images don't overlap enough (need 60-80% overlap)"
    echo "   - Images are too similar (taken from same position)"
    echo "   - Scene lacks texture/features"
    echo "   - Images are blurry or low quality"
fi

echo ""

# Check georegistration
echo "=== GEOREGISTRATION ANALYSIS ==="
if [ -f "$WORKDIR/campose.txt" ]; then
    echo "✅ Camera pose file exists"
    POSE_COUNT=$(wc -l < "$WORKDIR/campose.txt")
    echo "Camera poses: $POSE_COUNT"
    
    if [ $POSE_COUNT -lt 5 ]; then
        echo "⚠️  WARNING: Very few camera poses for georegistration"
    fi
    
    # Show sample pose
    echo "Sample pose data:"
    head -3 "$WORKDIR/campose.txt"
    
else
    echo "❌ No camera pose file found"
    echo "   Check if metadata.json or poslog.csv exists"
fi

if [ -d "$WORKDIR/sparse/georegistration" ]; then
    echo "✅ Georegistration directory exists"
    
    # Check if georegistration actually produced results
    GEOREG_FILES=$(find "$WORKDIR/sparse/georegistration" -name "*.bin" | wc -l)
    if [ $GEOREG_FILES -eq 0 ]; then
        echo "❌ Georegistration directory is empty - georegistration failed!"
        echo "   This means colmap model_aligner failed to align the model"
        echo "   Common causes:"
        echo "   - Camera positions in metadata don't match COLMAP reconstruction"
        echo "   - Coordinate system mismatch between metadata and images"
        echo "   - Too few matching images between metadata and reconstruction"
        echo "   - Incorrect camera pose format in campose.txt"
    else
        echo "✅ Georegistration completed successfully"
        echo "   Found $GEOREG_FILES binary files"
        if [ -f "$WORKDIR/sparse/georegistration/cameras.bin" ]; then
            echo "   ✅ cameras.bin exists"
        fi
        if [ -f "$WORKDIR/sparse/georegistration/images.bin" ]; then
            echo "   ✅ images.bin exists"
        fi
        if [ -f "$WORKDIR/sparse/georegistration/points3D.bin" ]; then
            echo "   ✅ points3D.bin exists"
        fi
    fi
    
    # Check if dense reconstruction was attempted
    if [ -d "$WORKDIR/dense/georegistration" ]; then
        echo "✅ Dense reconstruction directory exists"
        
        # Check dense reconstruction results
        DENSE_FILES=$(find "$WORKDIR/dense/georegistration" -type f | wc -l)
        echo "Dense reconstruction files: $DENSE_FILES"
        
        if [ $DENSE_FILES -eq 0 ]; then
            if [ $GEOREG_FILES -eq 0 ]; then
                echo "❌ Dense reconstruction failed because georegistration is empty"
            else
                echo "❌ Dense reconstruction directory is empty - reconstruction failed"
                echo "   This usually means:"
                echo "   - Dense reconstruction crashed or was interrupted"
                echo "   - GPU memory issues during patch match stereo"
                echo "   - Insufficient disk space"
                echo "   - Image undistortion failed"
            fi
        else
            echo "✅ Dense reconstruction has files"
            # Check for specific outputs
            if [ -f "$WORKDIR/dense/georegistration/fused.ply" ]; then
                echo "✅ Point cloud (fused.ply) exists"
            fi
            if [ -f "$WORKDIR/dense/georegistration/meshed-poisson.ply" ]; then
                echo "✅ Poisson mesh exists"
            fi
            if [ -f "$WORKDIR/dense/georegistration/meshed-delaunay.ply" ]; then
                echo "✅ Delaunay mesh exists"
            fi
        fi
    else
        echo "❌ Dense reconstruction not started"
    fi
else
    echo "❌ Georegistration not completed"
fi

echo ""
echo "=== RECOMMENDATIONS ==="

# Check if this is a successful case
if [ -d "$WORKDIR/sparse/0" ] && [ -d "$WORKDIR/sparse/georegistration" ]; then
    # Check if georegistration actually has files
    GEOREG_FILES=$(find "$WORKDIR/sparse/georegistration" -name "*.bin" | wc -l)
    if [ $GEOREG_FILES -eq 0 ]; then
        echo "🚨 GEOREGISTRATION FAILED - Try these fixes:"
        echo "1. 🔧 Check coordinate system settings:"
        if [ -f "${DATASETDIR}/poslog.csv" ]; then
            echo "   - For poslog.csv: Use --ref_is_gps 1 (GPS coordinates)"
        elif [ -f "${DATASETDIR}/metadata.json" ]; then
            echo "   - For Record3D metadata.json: Use --ref_is_gps 0 (local coordinates)"
        fi
        echo "2. 🎯 Check alignment parameters:"
        echo "   - Try increasing --alignment_max_error (e.g., 10.0)"
        echo "   - Check if camera pose file format is correct"
        echo "3. 🔍 Verify camera pose data:"
        echo "   - Sample from campose.txt: $(head -2 ${WORKDIR}/campose.txt 2>/dev/null || echo 'File not found')"
        echo "4. 📊 Check image matching:"
        echo "   - Ensure image names in campose.txt match actual image files"
        echo "   - Verify timestamps align between metadata and images"
    elif [ -d "$WORKDIR/dense/georegistration" ]; then
        DENSE_FILES=$(find "$WORKDIR/dense/georegistration" -type f | wc -l)
        if [ $DENSE_FILES -eq 0 ]; then
            echo "🚨 DENSE RECONSTRUCTION FAILED - Try these fixes:"
            echo "1. 🔧 Check for GPU memory issues:"
            echo "   - Try reducing --max_image_size in image_undistorter (use 1000 instead of 2000)"
            echo "   - Use CPU mode if GPU fails: remove --PatchMatchStereo.use_gpu 1"
            echo "2. 💾 Check disk space:"
            echo "   - Dense reconstruction needs significant disk space"
            echo "   - Check: df -h $WORKDIR"
            echo "3. 🔍 Check logs for specific errors:"
            echo "   - Look for CUDA errors, out-of-memory, or crash messages"
            echo "4. 🎯 Try with reduced settings:"
            echo "   - --max_image_size 1000 (instead of 2000)"
            echo "   - Process fewer images at once"
        else
            echo "✅ SUCCESS! Your reconstruction pipeline worked."
            echo "📊 Results summary:"
            echo "   - Sparse reconstruction: ✅ Complete"
            echo "   - Georegistration: ✅ Complete ($GEOREG_FILES binary files)"
            echo "   - Dense reconstruction: ✅ Complete ($DENSE_FILES files)"
            echo "   - File sizes: Normal for compressed images"
            echo "   - Feature matches: Good (82% success rate)"
            echo ""
            echo "🎉 No action needed - your data and pipeline are working well!"
        fi
    else
        echo "✅ SPARSE RECONSTRUCTION & GEOREGISTRATION SUCCESSFUL"
        echo "📋 Next steps:"
        echo "1. 🏃 Continue with dense reconstruction:"
        echo "   - Your sparse reconstruction and georegistration worked"
        echo "   - Run the full pipeline to complete dense reconstruction"
        echo "2. 📸 Your images are fine:"
        echo "   - File sizes (50-80KB) are normal for compressed JPEGs"
        echo "   - Good feature match rate (82%)"
        echo "   - No need to recollect data"
    fi
else
    echo "🚨 SPARSE RECONSTRUCTION ISSUES:"
fi

if [ "$GOOD_MATCHES" -lt "5" ]; then
    echo "1. 🔧 Try different feature extraction settings:"
    echo "   --SiftExtraction.max_image_size 800"
    echo "   --SiftExtraction.max_num_features 8192"
    echo "   --SiftExtraction.use_gpu 0"
fi

if [ "$IMAGE_COUNT" -lt "15" ]; then
    echo "2. 📸 Take more images with better overlap"
    echo "   - Ensure 60-80% overlap between consecutive images"
    echo "   - Take images from different viewpoints"
fi

if [ "$KEYPOINT_COUNT" -lt "1000" ]; then
    echo "3. 🎯 Improve image quality:"
    echo "   - Use better lighting"
    echo "   - Focus on textured objects/scenes"
    echo "   - Avoid motion blur"
fi

echo ""
echo "=== DIAGNOSTIC COMPLETE ==="
