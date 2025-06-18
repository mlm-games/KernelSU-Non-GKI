#!/bin/sh
set -eu

# --- Configuration ---
KERNEL_DIR=$(pwd)
KSU_NEXT_REPO="https://github.com/KernelSU-Next/KernelSU-Next.git"
KSU_OLD_REPO="https://github.com/mlm-games/KernelSU-Non-GKI.git"

# --- Default Script State ---
REPO_URL="$KSU_NEXT_REPO"
REPO_NAME="KernelSU-Next"
DEFCONFIG_PATH=""
CLEANUP_MODE=false
EXTRA_PYTHON_ARGS=""

# --- Function Definitions ---
display_usage() {
    echo "Usage: $0 [options]"
    echo "A unified script to integrate KernelSU into a kernel source tree."
    echo ""
    echo "Options:"
    echo "  --kernelsu-old          Use the mlm-games/KernelSU-Non-GKI repository (requires --defconfig)."
    echo "  --defconfig=<path>      Specify the path to your kernel defconfig file."
    echo "                          (e.g., --defconfig=arch/arm64/configs/vendor/my_defconfig)"
    echo "  --cleanup               Reverts all modifications made by this script."
    echo "  --disable-external-mods Pass this flag to the patch script to avoid modifying input.c/inode.c."
    echo "  -h, --help              Displays this usage information."
    echo ""
    echo "Examples:"
    echo "  # Integrate KernelSU-Next (default, no patch needed):"
    echo "  $0"
    echo ""
    echo "  # Integrate old KernelSU (with non-kprobe patches):"
    echo "  $0 --kernelsu-old --defconfig=arch/arm64/configs/my_defconfig"
    echo ""
    echo "  # Integrate old KernelSU but skip external module patches:"
    echo "  $0 --kernelsu-old --defconfig=arch/arm64/configs/my_defconfig --disable-external-mods"
}

initialize_variables() {
    if test -d "$KERNEL_DIR/common/drivers"; then
         DRIVER_DIR="$KERNEL_DIR/common/drivers"
    elif test -d "$KERNEL_DIR/drivers"; then
         DRIVER_DIR="$KERNEL_DIR/drivers"
    else
         echo "[ERROR] 'drivers/' directory not found. Are you in the kernel root?" >&2
         exit 127
    fi

    DRIVER_MAKEFILE="$DRIVER_DIR/Makefile"
    DRIVER_KCONFIG="$DRIVER_DIR/Kconfig"
}

perform_cleanup() {
    echo "[+] Starting cleanup..."

    # If the python script exists, it means the old repo was likely used. Run its cleanup.
    if [ -f "$KERNEL_DIR/KernelSU/scripts/integrate-no-kprobe.py" ]; then
        echo "[+] Found non-kprobe script, attempting to revert its patches..."
        # The python script needs a defconfig arg even for disabling, but it won't be used.
        # We pass a dummy value to satisfy argparse.
        python3 "$KERNEL_DIR/KernelSU/scripts/integrate-no-kprobe.py" "dummy_defconfig" --disable-ksu
        echo "[-] Python script cleanup executed."
    fi

    [ -L "$DRIVER_DIR/kernelsu" ] && rm "$DRIVER_DIR/kernelsu" && echo "[-] Symlink removed."
    grep -q "kernelsu" "$DRIVER_MAKEFILE" && sed -i '/kernelsu/d' "$DRIVER_MAKEFILE" && echo "[-] Makefile reverted."
    grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" && sed -i '/source "drivers\/kernelsu\/Kconfig"/d' "$DRIVER_KCONFIG" && echo "[-] Kconfig reverted."
    
    if [ -d "$KERNEL_DIR/KernelSU" ]; then
        echo "[+] Removing KernelSU submodule..."
        git submodule deinit -f "$KERNEL_DIR/KernelSU" >/dev/null 2>&1 || true
        rm -rf "$KERNEL_DIR/.git/modules/KernelSU" || true
        git rm -f KernelSU >/dev/null 2>&1 || true
        rm -rf "$KERNEL_DIR/KernelSU" && echo "[-] KernelSU directory deleted."
    fi

        # If u had manually deleted the KernelSU directory
    rm -rf "$KERNEL_DIR/.git/modules/KernelSU" || true
    #rm -rf "$KERNEL_DIR/include/ksu_hook.h"
    
    echo '[+] Cleanup complete.'
}

setup_kernelsu() {
    echo "[+] Setting up $REPO_NAME..."
    
    # Add submodule if it doesn't exist, then update it
    test -d "$KERNEL_DIR/KernelSU" || git submodule add "$REPO_URL" KernelSU
    git submodule update --init --recursive

    # Create symlink to the KernelSU driver directory
    ln -sfn "$(realpath --relative-to="$DRIVER_DIR" "$KERNEL_DIR/KernelSU/kernel")" "$DRIVER_DIR/kernelsu" && echo "[+] Symlink to kernelsu created."
    
    # Add entries in Makefile and Kconfig if they don't already exist
    grep -q "kernelsu" "$DRIVER_MAKEFILE" || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "$DRIVER_MAKEFILE" && echo "[+] Modified Makefile."
    grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" || sed -i '$isource "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" && echo "[+] Modified Kconfig."

    # If using the old repo, run the python patch script from repo
    if [ "$REPO_NAME" = "KernelSU (Old)" ]; then
        if [ -z "$DEFCONFIG_PATH" ]; then
            echo "[ERROR] The --kernelsu-old flag requires a --defconfig=<path> argument." >&2
            display_usage
            exit 1
        fi
        if [ ! -f "$DEFCONFIG_PATH" ]; then
            echo "[ERROR] Defconfig file not found at: $DEFCONFIG_PATH" >&2
            exit 1
        fi
        
        echo "[+] Running non-kprobe integration script on '$DEFCONFIG_PATH'..."
        python3 "$KERNEL_DIR/KernelSU/scripts/integrate-no-kprobe.py" "$DEFCONFIG_PATH" $EXTRA_PYTHON_ARGS
        echo "[+] Python patch script executed successfully."
    else 
        echo "[+] Running non-kprobe integration script on '$DEFCONFIG_PATH'..."
        curl -LSs "https://raw.githubusercontent.com/mlm-games/KernelSU-Non-GKI/refs/heads/main/scripts/integrate-no-kprobe.py" | python3 "$DEFCONFIG_PATH" $EXTRA_PYTHON_ARGS
        echo "[+] Python patch script executed successfully."
    fi

    # Add the ksu_hook.h to include folder.
    echo '[+] Integration complete.'
    cp "$KERNEL_DIR/KernelSU/kernel/include/ksu_hook.h" "$KERNEL_DIR/include/ksu_hook.h" && echo "[+] Added hookfile to include."
    echo '[+] Done.'

    echo '[+] Integration complete.'
}


# --- Argument Parsing ---
for arg in "$@"; do
  case "$arg" in
    --kernelsu-old)
      REPO_URL="$KSU_OLD_REPO"
      REPO_NAME="KernelSU (Old)"
      ;;
    --defconfig=*)
      DEFCONFIG_PATH="${arg#*=}"
      ;;
    --cleanup)
      CLEANUP_MODE=true
      ;;
    --disable-external-mods)
      EXTRA_PYTHON_ARGS="$EXTRA_PYTHON_ARGS --disable-external-mods"
      ;;
    -h|--help)
      display_usage
      exit 0
      ;;
    *)
      # Ignore unknown arguments for now, or handle them as needed
      ;;
  esac
done

# --- Main Script Logic ---
initialize_variables

if [ "$CLEANUP_MODE" = true ]; then
    perform_cleanup
else
    # Run cleanup before setup to ensure a clean state
    perform_cleanup
    setup_kernelsu
fi
