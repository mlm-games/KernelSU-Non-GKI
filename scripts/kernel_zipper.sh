#!/bin/bash

# Set variables
SCRIPT=$(readlink -f "$0")
SCRIPT_PATH=$(dirname "$SCRIPT")

ANYKERNEL_REPO="https://github.com/mlm-games/AnyKernel3.git"
ANYKERNEL_DIR="$SCRIPT_PATH/../../AnyKernel3"
KERNEL_DIR="$SCRIPT_PATH/../.."  # Replace with actual path if yours is different
FINAL_KERNEL_ZIP="RuskKernel.zip"

# Initialize variables
DTB_FILE=""
DTBO_FILE=""
KERNEL_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dtb=*)
            DTB_FILE="${1#*=}"
            shift
            ;;
        --dtbo=*)
            DTBO_FILE="${1#*=}"
            shift
            ;;
        --kernel=*)
            KERNEL_FILE="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $1 (Available -- options: kernel, dtb, dtbo)"
            exit 1
            ;;
    esac
done

# Clone AnyKernel3 repository

if [ -d "$ANYKERNEL_DIR" ]; then
    rm -rf $ANYKERNEL_DIR
fi

git clone "$ANYKERNEL_REPO" "$ANYKERNEL_DIR" --depth=1

# Function to find and copy kernel image
find_and_copy_kernel() {
    local search_dirs=("arch/arm/boot" "arch/arm64/boot" "out/arch/arm/boot" "out/arch/arm64/boot")
    local kernel_names=("zImage-dtb" "Image.gz-dtb" "Image.gz"  "Image" "kernel")
    
    if [ -f "$KERNEL_FILE" ]; then
        cp "$KERNEL_FILE" "$ANYKERNEL_DIR/"
        echo "Copied kernel: $dir/$KERNEL_FILE"
        return 0
    fi

    for dir in "${search_dirs[@]}"; do
        if [ -f "$KERNEL_DIR/$dir/$KERNEL_FILE" ]; then
            cp "$KERNEL_DIR/$dir/$KERNEL_FILE" "$ANYKERNEL_DIR/"
            echo "Copied kernel: $dir/$KERNEL_FILE"
            return 0
        fi
            
        for name in "${kernel_names[@]}"; do
            if [ -f "$KERNEL_DIR/$dir/$name" ]; then
                cp "$KERNEL_DIR/$dir/$name" "$ANYKERNEL_DIR/"
                echo "Copied kernel: $dir/$name"
                return 0
            fi
        done
    done

    echo "No kernel image found!"
    return 1
}

# Function to copy DTB
copy_dtb() {
    if [ -f "$KERNEL_DIR/$DTB_FILE" ]; then
        cp "$KERNEL_DIR/$DTB_FILE" "$ANYKERNEL_DIR/"
        echo "Copied DTB: $DTB_FILE"
    else
        echo "DTB file not found: $DTB_FILE"
        exit
    fi
}

# Function to copy DTBO
copy_dtbo() {
    if [ -f "$KERNEL_DIR/$DTBO_FILE" ]; then
        cp "$KERNEL_DIR/$DTBO_FILE" "$ANYKERNEL_DIR/"
        echo "Copied DTBO: $DTBO_FILE"
    else
        echo "DTBO file not found: $DTBO_FILE"
        exit
    fi
}

# Main execution
find_and_copy_kernel

if [ -n "$DTB_FILE" ]; then
    copy_dtb
fi

if [ -n "$DTBO_FILE" ]; then
    copy_dtbo
fi

# Create AnyKernel zip
cd "$ANYKERNEL_DIR"
zip -r9 "$FINAL_KERNEL_ZIP" * -x .git README.md kernel_zipper.sh *placeholder

mv $FINAL_KERNEL_ZIP $KERNEL_DIR/$FINAL_KERNEL_ZIP

echo "AnyKernel zip created: $FINAL_KERNEL_ZIP"