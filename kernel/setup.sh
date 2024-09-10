#!/bin/sh
set -eu

GKI_ROOT=$(pwd)

display_usage() {
    echo "Usage: $0 [--cleanup | <commit-or-tag>]"
    echo "  --cleanup:              Cleans up previous modifications made by the script."
    echo "  <commit-or-tag>:        Sets up or updates the KernelSU to specified tag or commit."
    echo "  -h, --help:             Displays this usage information."
    echo "  (no args):              Sets up or updates the KernelSU environment to the latest tagged version."
}

initialize_variables() {
    if test -d "$GKI_ROOT/common/drivers"; then
         DRIVER_DIR="$GKI_ROOT/common/drivers"
    elif test -d "$GKI_ROOT/drivers"; then
         DRIVER_DIR="$GKI_ROOT/drivers"
    else
         echo '[ERROR] "drivers/" directory not found.'
         exit 127
    fi

    DRIVER_MAKEFILE=$DRIVER_DIR/Makefile
    DRIVER_KCONFIG=$DRIVER_DIR/Kconfig
}

# Reverts modifications made by this script
perform_cleanup() {
    echo "[+] Cleaning up..."
    [ -L "$DRIVER_DIR/kernelsu" ] && rm "$DRIVER_DIR/kernelsu" && echo "[-] Symlink removed."
    grep -q "kernelsu" "$DRIVER_MAKEFILE" && sed -i '/kernelsu/d' "$DRIVER_MAKEFILE" && echo "[-] Makefile reverted."
    grep -q "drivers/kernelsu/Kconfig" "$DRIVER_KCONFIG" && sed -i '/drivers\/kernelsu\/Kconfig/d' "$DRIVER_KCONFIG" && echo "[-] Kconfig reverted."
    if [ -d "$GKI_ROOT/KernelSU" ]; then
        rm -rf "$GKI_ROOT/KernelSU" && echo "[-] KernelSU directory deleted."
    fi
}

# Sets up or update KernelSU environment
setup_kernelsu() {
    local ksu_dir="$GKI_ROOT/KernelSU"
    local current_tag

    echo "[+] Setting up KernelSU environment..."

    # Clone KernelSU if it doesn't exist
    if [[ ! -d "$ksu_dir" ]]; then
        git clone https://github.com/mlm-games/KernelSU-Non-GKI "$ksu_dir" || { echo "[-] Failed to clone KernelSU repository."; return 1; }
        echo "[+] KernelSU repository cloned."
    fi

    cd "$ksu_dir" || { echo "[-] Unable to change directory to $ksu_dir"; return 1; }

    # Stash any local changes
    git stash 2>/dev/null && echo "[-] Stashed current changes."

    # Ensure we're on the main branch or a tagged version
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        current_tag=$(git describe --tags --exact-match 2>/dev/null)
        if [[ -z "$current_tag" ]]; then
            git checkout main && echo "[-] Switched to main branch."
        fi
    else
        echo "[-] Not in a git repository, skipping branch check."
    fi

    # Pull the latest changes
    git pull --ff-only && echo "[+] Updated repository." || { echo "[-] Failed to update repository."; return 1; }

    # Checkout to the specified or latest tag
    if [[ -z "${1-}" ]]; then
        git checkout $(git describe --tags $(git rev-list --tags --max-count=1)) && echo "[-] Checked out latest tag."
    else
        git checkout "$1" 2>/dev/null && echo "[-] Checked out $1." || { echo "[-] Failed to checkout $1, staying on current branch/tag."; }
    fi

    # Return to the driver directory
    cd "$DRIVER_DIR" || { echo "[-] Unable to return to $DRIVER_DIR"; return 1; }

    # Create symlink
    ln -sfn "$(realpath --relative-to="$DRIVER_DIR" "$ksu_dir/kernel")" "kernelsu" && echo "[+] Symlink to kernelsu created."

    # Modify Makefile if necessary
    if ! grep -q "kernelsu" "$DRIVER_MAKEFILE"; then
        echo -e "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "$DRIVER_MAKEFILE"
        echo "[+] Added kernelsu to Makefile."
    fi

    # Modify Kconfig if necessary
    if ! grep -q "source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG"; then
        sed -i '/endmenu/i\source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" && echo "[+] Added kernelsu to Kconfig."
    fi

    echo '[+] KernelSU setup completed.'
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
