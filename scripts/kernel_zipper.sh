#!/bin/bash

# Set variables
# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPT_PATH=$(dirname "$SCRIPT")
ANYKERNEL_REPO="https://github.com/mlm-games/AnyKernel3.git"
ANYKERNEL_DIR="$SCRIPT_PATH/../../AnyKernel3"
KERNEL_SOURCE_DIR="$SCRIPT_PATH/../.."  # Replace with actual path if yours is diff.
FINAL_KERNEL_ZIP="RuskKernel.zip"

# Clone AnyKernel3 repository
git clone "$ANYKERNEL_REPO" "$ANYKERNEL_DIR" --depth=1

# Function to find and copy kernel image
find_and_copy_kernel() {
    local search_dirs=("arch/arm/boot" "arch/arm64/boot" "out/arch/arm/boot" "out/arch/arm64/boot")
    local kernel_names=("zImage-dtb" "Image.gz-dtb" "Image.gz"  "Image" "kernel")

    for dir in "${search_dirs[@]}"; do
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

# Function to find and copy DTB/DTBO
find_and_copy_dtb_dtbo() {
    local search_dirs=("arch/arm/boot/dts" "arch/arm64/boot/dts" "out/arch/arm/boot/dts" "out/arch/arm64/boot/dts")
    local dtb_patterns=("*.dtb" "*.dtbo")

    for dir in "${search_dirs[@]}"; do
        for pattern in "${dtb_patterns[@]}"; do
            local file=$(find "$KERNEL_DIR/$dir" -name "$pattern" -print -quit)
            if [ -n "$file" ]; then
                cp "$file" "$ANYKERNEL_DIR/"
                echo "Copied DTB/DTBO: $file"
                return 0
            fi
        done
    done

    echo "No DTB/DTBO file found!"
    return 0  # Return 0 even if no file found, as it's optional
}

# Main execution
find_and_copy_kernel
find_and_copy_dtb_dtbo

# Create AnyKernel zip
cd "$ANYKERNEL_DIR"
zip -r9 "$FINAL_KERNEL_ZIP" * -x .git README.md *placeholder

echo "AnyKernel zip created: $FINAL_KERNEL_ZIP"
