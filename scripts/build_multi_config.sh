#!/bin/bash

# Multi-configuration emu build script for XiangShan
# This script allows building and managing multiple emu binaries for different configurations

set -e

# Default values
CONFIG=${CONFIG:-"DefaultConfig"}
BUILD_SUFFIX=${BUILD_SUFFIX:-""}
CLEAN_ONLY=false
BUILD_ONLY=false
LIST_CONFIGS=false
HELP=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG="$2"
            shift 2
            ;;
        -s|--suffix)
            BUILD_SUFFIX="$2"
            shift 2
            ;;
        --clean)
            CLEAN_ONLY=true
            shift
            ;;
        --build)
            BUILD_ONLY=true
            shift
            ;;
        --list)
            LIST_CONFIGS=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Show help
if [ "$HELP" = true ]; then
    cat << EOF
Usage: $0 [OPTIONS]

Multi-configuration emu build script for XiangShan

OPTIONS:
    -c, --config CONFIG     Configuration to build (default: DefaultConfig)
    -s, --suffix SUFFIX     Build suffix for different configs (e.g., l3_1mb, l3_2mb)
    --clean                 Clean build directory for current config
    --build                 Build emu for current config only
    --list                  List available configurations
    -h, --help              Show this help message

EXAMPLES:
    # Build emu with DefaultConfig
    $0 --config DefaultConfig --suffix default

    # Build emu with custom L3 cache size
    $0 --config DefaultConfig --suffix l3_1mb

    # Clean build for specific config
    $0 --config DefaultConfig --suffix l3_1mb --clean

    # List available configs
    $0 --list

ENVIRONMENT VARIABLES:
    CONFIG          Default configuration (can be overridden with -c)
    BUILD_SUFFIX    Default build suffix (can be overridden with -s)

EOF
    exit 0
fi

# List available configurations
if [ "$LIST_CONFIGS" = true ]; then
    echo "Available configurations in XiangShan:"
    echo "======================================"
    echo "1. DefaultConfig - Default configuration"
    echo "2. MinimalConfig - Minimal configuration for testing"
    echo "3. FpgaDefaultConfig - FPGA-optimized configuration"
    echo "4. MediumConfig - Medium-sized configuration"
    echo "5. KunminghuV2Config - Kunminghu V2 configuration"
    echo ""
    echo "You can also create custom configurations by modifying:"
    echo "  src/main/scala/top/Configs.scala"
    exit 0
fi

# Validate configuration
if [ -z "$CONFIG" ]; then
    echo "Error: Configuration must be specified"
    exit 1
fi

# Create build directory with suffix
if [ -n "$BUILD_SUFFIX" ]; then
    BUILD_DIR="build_${BUILD_SUFFIX}"
    export BUILD_DIR
    echo "Using build directory: $BUILD_DIR"
else
    BUILD_DIR="build"
    echo "Using default build directory: $BUILD_DIR"
fi

# Function to clean build directory
clean_build() {
    echo "Cleaning build directory: $BUILD_DIR"
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        echo "Build directory cleaned."
    else
        echo "Build directory does not exist."
    fi
}

# Function to build emu
build_emu() {
    echo "Building emu for configuration: $CONFIG"
    echo "Build directory: $BUILD_DIR"
    echo "Build suffix: $BUILD_SUFFIX"
    
    # Set environment variables for build
    export CONFIG
    if [ -n "$BUILD_SUFFIX" ]; then
        export BUILD_DIR
    fi
    
    # Build RTL and emu
    echo "Step 1: Generating RTL files..."
    make verilog CONFIG="$CONFIG" -j$(nproc)
    
    echo "Step 2: Building emu..."
    make emu CONFIG="$CONFIG" -j$(nproc)
    
    echo "Build completed successfully!"
    echo "Emu binary location: $BUILD_DIR/emu"
}

# Function to create symlink for easy access
create_symlink() {
    if [ -n "$BUILD_SUFFIX" ]; then
        SYMLINK_NAME="emu_${BUILD_SUFFIX}"
        if [ -L "$SYMLINK_NAME" ]; then
            rm "$SYMLINK_NAME"
        fi
        ln -sf "$BUILD_DIR/emu" "$SYMLINK_NAME"
        echo "Created symlink: $SYMLINK_NAME -> $BUILD_DIR/emu"
    fi
}

# Function to show build info
show_build_info() {
    echo ""
    echo "Build Information:"
    echo "=================="
    echo "Configuration: $CONFIG"
    echo "Build directory: $BUILD_DIR"
    if [ -n "$BUILD_SUFFIX" ]; then
        echo "Build suffix: $BUILD_SUFFIX"
        echo "Symlink: emu_${BUILD_SUFFIX}"
    fi
    
    if [ -f "$BUILD_DIR/emu" ]; then
        echo "Emu binary: $BUILD_DIR/emu"
        echo "Emu size: $(ls -lh "$BUILD_DIR/emu" | awk '{print $5}')"
        echo "Build time: $(stat -c %y "$BUILD_DIR/emu")"
    else
        echo "Emu binary: Not found"
    fi
}

# Main execution
if [ "$CLEAN_ONLY" = true ]; then
    clean_build
    exit 0
fi

if [ "$BUILD_ONLY" = true ]; then
    build_emu
    create_symlink
    show_build_info
    exit 0
fi

# Default: clean and build
clean_build
build_emu
create_symlink
show_build_info

echo ""
echo "Usage examples:"
echo "  # Run CoreMark with this configuration"
echo "  ./emu_${BUILD_SUFFIX:-default} -i /path/to/coremark.riscv"
echo ""
echo "  # Run with different workload"
echo "  ./emu_${BUILD_SUFFIX:-default} -i /path/to/workload.riscv" 