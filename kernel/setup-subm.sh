#!/bin/sh
set -eu

KERNEL_DIR=$(pwd)

# Define repository URLs
KSU_NEXT_REPO="https://github.com/KernelSU-Next/KernelSU-Next.git"
KSU_OLD_REPO="https://github.com/mlm-games/KernelSU-Non-GKI.git"

# Default to KernelSU-Next
REPO_URL="$KSU_NEXT_REPO"
REPO_NAME="KernelSU-Next"

# Check for the --kernelsu-old flag
for arg in "$@"; do
  if [ "$arg" = "--kernelsu-old" ]; then
    REPO_URL="$KSU_OLD_REPO"
    REPO_NAME="KernelSU (Old)"
    echo "[+] Flag --kernelsu-old detected. Using the old repository."
  fi
done

display_usage() {
    echo "Usage: $0 [--cleanup | --kernelsu-old | <commit-or-tag>]"
    echo "  --cleanup:              Cleans up previous modifications made by the script."
    echo "  --kernelsu-old:         Use the original mlm-games/KernelSU-Non-GKI repository."
    echo "  <commit-or-tag>:        Sets up or updates the KernelSU to specified tag or commit."
    echo "  -h, --help:             Displays this usage information."
    echo "  (no args):              Sets up KernelSU-Next by default."
}

initialize_variables() {
    if test -d "$KERNEL_DIR/common/drivers"; then
         DRIVER_DIR="$KERNEL_DIR/common/drivers"
    elif test -d "$KERNEL_DIR/drivers"; then
         DRIVER_DIR="$KERNEL_DIR/drivers"
    else
         echo '[ERROR] "drivers/" directory not found.'
         exit 127
    fi

    DRIVER_MAKEFILE=$DRIVER_DIR/Makefile
    DRIVER_KCONFIG=$DRIVER_DIR/Kconfig
}

# Reverts modifications made by this script, remove the submodule.
perform_cleanup() {
    echo "[+] Cleaning up..."
    [ -L "$DRIVER_DIR/kernelsu" ] && rm "$DRIVER_DIR/kernelsu" && echo "[-] Symlink removed."
    grep -q "kernelsu" "$DRIVER_MAKEFILE" && sed -i '/kernelsu/d' "$DRIVER_MAKEFILE" && echo "[-] Makefile reverted."
    grep -q "drivers/kernelsu/Kconfig" "$DRIVER_KCONFIG" && sed -i '/drivers\/kernelsu\/Kconfig/d' "$DRIVER_KCONFIG" && echo "[-] Kconfig reverted."
    
    if [ -d "$KERNEL_DIR/KernelSU" ]; then
        echo "[+] Removing KernelSU submodule..."
        git submodule deinit -f "$KERNEL_DIR/KernelSU" || true
        rm -rf "$KERNEL_DIR/KernelSU" && echo "[-] KernelSU directory deleted."

        rm -rf "$KERNEL_DIR/.git/modules/KernelSU" || true
        git stage KernelSU
    fi
    # If u had manually deleted the KernelSU directory
    rm -rf "$KERNEL_DIR/.git/modules/KernelSU" || true
    #rm -rf "$KERNEL_DIR/include/ksu_hook.h"
}

# Sets up or update KernelSU environment
setup_kernelsu() {
    echo "[+] Setting up $REPO_NAME..."
    
    # Use the selected REPO_URL
    test -d "$KERNEL_DIR/KernelSU" || git submodule add "$REPO_URL" KernelSU
    git submodule update --init --recursive

    ln -sfn "$(realpath --relative-to="$DRIVER_DIR" "$KERNEL_DIR/KernelSU/kernel")" "$DRIVER_DIR/kernelsu" && echo "[+] Symlink to kernelsu created."
    
    # Later when i have tags
    # if [ -n "$1" ]; then
    #     (cd KernelSU && git checkout "$1") && echo "[-] Checked out $1." || echo "[-] Failed to checkout $1."
    # fi
    
    # Add entries in Makefile and Kconfig if not already existing
    grep -q "kernelsu" "$DRIVER_MAKEFILE" || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "$DRIVER_MAKEFILE" && echo "[+] Modified Makefile."
    grep -q "source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG" || sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG" && echo "[+] Modified Kconfig."

    # Add the ksu_hook.h to include folder.
    cp "$KERNEL_DIR/KernelSU/kernel/include/ksu_hook.h" "$KERNEL_DIR/include/ksu_hook.h" && echo "[+] Added hookfile to include."
    echo '[+] Done.'
}

# Process command-line arguments
if [ "$#" -gt 0 ]; then
    case "$1" in
        -h|--help)
            display_usage
            exit 0
            ;;
        --cleanup)
            initialize_variables
            perform_cleanup
            exit 0
            ;;
    esac
fi

initialize_variables
setup_kernelsu "$@"
