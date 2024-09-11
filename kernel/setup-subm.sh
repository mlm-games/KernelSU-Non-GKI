#!/bin/sh
set -eu

KERNEL_DIR=$(pwd)

display_usage() {
    echo "Usage: $0 [--cleanup | <commit-or-tag>]"
    echo "  --cleanup:              Cleans up previous modifications made by the script."
    echo "  <commit-or-tag>:        Sets up or updates the KernelSU to specified tag or commit."
    echo "  -h, --help:             Displays this usage information."
    echo "  (no args):              Sets up or updates the KernelSU environment to the latest tagged version."
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
}

# Sets up or update KernelSU environment
setup_kernelsu() {
    echo "[+] Setting up KernelSU..."
    test -d "$KERNEL_DIR/KernelSU" || git submodule add https://github.com/mlm-games/KernelSU-Non-GKI KernelSU
    git submodule update --init --recursive

    ln -sfn "$(realpath --relative-to="$DRIVER_DIR" "$KERNEL_DIR/KernelSU/kernel")" "$DRIVER_DIR/kernelsu" && echo "[+] Symlink to kernelsu created."

    # Later when i have tags
    # if [ -n "$1" ]; then
    #     (cd KernelSU && git checkout "$1") && echo "[-] Checked out $1." || echo "[-] Failed to checkout $1."
    # fi
    
    # Add entries in Makefile and Kconfig if not already existing
    grep -q "kernelsu" "$DRIVER_MAKEFILE" || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "$DRIVER_MAKEFILE" && echo "[+] Modified Makefile."
    grep -q "source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG" || sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG" && echo "[+] Modified Kconfig."
    echo '[+] Done.'
}

# Process command-line arguments
if [ "$#" -eq 0 ]; then
    initialize_variables
    setup_kernelsu
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    display_usage
elif [ "$1" = "--cleanup" ]; then
    initialize_variables
    perform_cleanup
else
    initialize_variables
    setup_kernelsu "$@"
fi