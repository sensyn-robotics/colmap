#!/bin/bash
# Docker management utilities for COLMAP-Sensyn

show_help() {
    echo "COLMAP-Sensyn Docker Manager"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  build       Build custom COLMAP-sensyn image with pre-installed dependencies"
    echo "  shell       Start interactive Docker shell for debugging"
    echo "  run         Run pipeline on a dataset (alias for run_pipeline_docker.sh)"
    echo "  clean       Remove all COLMAP Docker images"
    echo "  status      Show Docker image status and sizes"
    echo "  test        Test the pipeline with built-in dataset"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build                    # Build custom image (recommended first step)"
    echo "  $0 run ./dataset            # Run pipeline on dataset"
    echo "  $0 run ./dataset --force-dense  # Force re-run dense reconstruction"
    echo "  $0 shell                    # Interactive debugging shell"
    echo "  $0 status                   # Check available images"
}

build_image() {
    echo "=== 🔨 BUILDING CUSTOM COLMAP IMAGE ==="
    ./scripts/sensyn/build_custom_image.sh
}

start_shell() {
    echo "=== 🐚 STARTING INTERACTIVE SHELL ==="
    ./scripts/sensyn/start_sensyn_docker.sh
}

run_pipeline() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 run <dataset_path> [options]"
        echo "Example: $0 run ./dataset --force-sparse"
        exit 1
    fi
    ./scripts/sensyn/run_pipeline_docker.sh "$@"
}

clean_images() {
    echo "=== 🧹 CLEANING DOCKER IMAGES ==="
    echo "This will remove all COLMAP-related Docker images"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker rmi colmap-sensyn:latest 2>/dev/null || echo "No colmap-sensyn:latest image found"
        docker rmi colmap:latest 2>/dev/null || echo "No colmap:latest image found"
        docker rmi colmap/colmap:latest 2>/dev/null || echo "No colmap/colmap:latest image found"
        echo "✅ Cleanup complete"
    else
        echo "Cancelled"
    fi
}

show_status() {
    echo "=== 📊 DOCKER IMAGE STATUS ==="
    echo ""
    
    # Check for custom image
    if docker image inspect colmap-sensyn:latest >/dev/null 2>&1; then
        SIZE=$(docker image inspect colmap-sensyn:latest --format='{{.Size}}' | numfmt --to=iec)
        echo "✅ Custom COLMAP-sensyn image: $SIZE (RECOMMENDED)"
    else
        echo "❌ Custom COLMAP-sensyn image: Not built"
        echo "   💡 Run: $0 build"
    fi
    
    # Check for local COLMAP build
    if docker image inspect colmap:latest >/dev/null 2>&1; then
        SIZE=$(docker image inspect colmap:latest --format='{{.Size}}' | numfmt --to=iec)
        echo "✅ Local COLMAP image: $SIZE"
    else
        echo "❌ Local COLMAP image: Not found"
    fi
    
    # Check for official image
    if docker image inspect colmap/colmap:latest >/dev/null 2>&1; then
        SIZE=$(docker image inspect colmap/colmap:latest --format='{{.Size}}' | numfmt --to=iec)
        echo "✅ Official COLMAP image: $SIZE"
    else
        echo "❌ Official COLMAP image: Not pulled"
    fi
    
    echo ""
    echo "💡 For fastest startup, use the custom image: $0 build"
}

test_pipeline() {
    echo "=== 🧪 TESTING PIPELINE ==="
    if [ -d "./dataset" ] && [ -d "./dataset/images" ] && ([ -f "./dataset/poslog.csv" ] || [ -f "./dataset/metadata.json" ]); then
        echo "Using built-in test dataset..."
        ./scripts/sensyn/run_pipeline_docker.sh ./dataset --help
    else
        echo "❌ No test dataset found at ./dataset/"
        echo "Test dataset should contain:"
        echo "  - images/ directory with photos"
        echo "  - poslog.csv or metadata.json"
        echo ""
        echo "You can test with your own dataset:"
        echo "  $0 run /path/to/your/dataset"
    fi
}

case "$1" in
    build)
        build_image
        ;;
    shell)
        start_shell
        ;;
    run)
        shift
        run_pipeline "$@"
        ;;
    clean)
        clean_images
        ;;
    status)
        show_status
        ;;
    test)
        test_pipeline
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
