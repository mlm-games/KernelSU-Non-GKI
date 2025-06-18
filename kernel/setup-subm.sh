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
    echo "  --kernelsu-old          Use the mlm-games/KernelSU-Non-GKI repository."
    echo "  --defconfig=<path>      Specify the path to your kernel defconfig file (required)."
    echo "                          (e.g., --defconfig=arch/arm64/configs/vendor/my_defconfig)"
    echo "  --cleanup               Reverts all modifications made by this script."
    echo "  --disable-external-mods Pass this flag to the patch script to avoid modifying input.c/inode.c."
    echo "  -h, --help              Displays this usage information."
    echo ""
    echo "Examples:"
    echo "  # Integrate KernelSU-Next:"
    echo "  $0 --defconfig=arch/arm64/configs/my_defconfig"
    echo ""
    echo "  # Integrate old KernelSU:"
    echo "  $0 --kernelsu-old --defconfig=arch/arm64/configs/my_defconfig"
    echo ""
    echo "  # Integrate but skip external module patches:"
    echo "  $0 --defconfig=arch/arm64/configs/my_defconfig --disable-external-mods"
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

    # If the python script exists, run its cleanup
    if [ -f "$KERNEL_DIR/KernelSU/scripts/integrate-no-kprobe.py" ]; then
        echo "[+] Found non-kprobe script, attempting to revert its patches..."
        # The python script needs a defconfig arg even for disabling
        # Try to find a defconfig file if not provided
        if [ -z "$DEFCONFIG_PATH" ]; then
            # Look for common defconfig locations
            for config in arch/arm64/configs/*_defconfig arch/arm64/configs/vendor/*_defconfig; do
                if [ -f "$config" ]; then
                    DEFCONFIG_PATH="$config"
                    break
                fi
            done
        fi
        
        if [ -n "$DEFCONFIG_PATH" ]; then
            python3 "$KERNEL_DIR/KernelSU/scripts/integrate-no-kprobe.py" "$DEFCONFIG_PATH" --disable-ksu
            echo "[-] Python script cleanup executed."
        else
            echo "[WARNING] Could not find defconfig for cleanup. Manual cleanup may be ."
        fi
    fi

    [ -L "$DRIVER_DIR/kernelsu" ] && rm "$DRIVER_DIR/kernelsu" && echo "[-] Symlink removed."
    grep -q "kernelsu" "$DRIVER_MAKEFILE" 2>/dev/null && sed -i '/kernelsu/d' "$DRIVER_MAKEFILE" && echo "[-] Makefile reverted."
    grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" 2>/dev/null && sed -i '/source "drivers\/kernelsu\/Kconfig"/d' "$DRIVER_KCONFIG" && echo "[-] Kconfig reverted."
    
    if [ -d "$KERNEL_DIR/KernelSU" ]; then
        echo "[+] Removing KernelSU submodule..."
        git submodule deinit -f "$KERNEL_DIR/KernelSU" >/dev/null 2>&1 || true
        rm -rf "$KERNEL_DIR/.git/modules/KernelSU" || true
        git rm -f KernelSU >/dev/null 2>&1 || true
        rm -rf "$KERNEL_DIR/KernelSU" && echo "[-] KernelSU directory deleted."
    fi

    # Clean up any remaining git modules
    rm -rf "$KERNEL_DIR/.git/modules/KernelSU" 2>/dev/null || true
    
    # Remove the ksu_hook.h if it exists
    [ -f "$KERNEL_DIR/include/ksu_hook.h" ] && rm "$KERNEL_DIR/include/ksu_hook.h" && echo "[-] ksu_hook.h removed from include."
    
    echo '[+] Cleanup complete.'
}

setup_kernelsu() {
    echo "[+] Setting up $REPO_NAME..."
    
    # Check if defconfig is provided ( for both repos now)
    # if [ -z "$DEFCONFIG_PATH" ]; then
    #     echo "[ERROR] The --defconfig=<path> argument is required." >&2
    #     display_usage
    #     exit 1
    # fi
    # if [ ! -f "$DEFCONFIG_PATH" ]; then
    #     echo "[ERROR] Defconfig file not found at: $DEFCONFIG_PATH" >&2
    #     exit 1
    # fi
    
    # Add submodule if it doesn't exist, then update it
    if [ ! -d "$KERNEL_DIR/KernelSU" ]; then
        git submodule add "$REPO_URL" KernelSU
    fi
    git submodule update --init --recursive

    # Create symlink to the KernelSU driver directory
    ln -sfn "$(realpath --relative-to="$DRIVER_DIR" "$KERNEL_DIR/KernelSU/kernel")" "$DRIVER_DIR/kernelsu"
    echo "[+] Symlink to kernelsu created."
    
    # Add entries in Makefile and Kconfig if they don't already exist
    if ! grep -q "kernelsu" "$DRIVER_MAKEFILE"; then
        printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "$DRIVER_MAKEFILE"
        echo "[+] Modified Makefile."
    fi
    
    if ! grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG"; then
        sed -i '$isource "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG"
        echo "[+] Modified Kconfig."
    fi
    
    # Run the python patch script
    # echo "[+] Running non-kprobe integration script on '$DEFCONFIG_PATH'..."
    
    # Check if the script exists in the submodule
    if [ -f "$KERNEL_DIR/KernelSU/scripts/integrate-no-kprobe.py" ]; then
        echo ".py File exists"
        # Use the script from the submodule
        # python3 "$KERNEL_DIR/KernelSU/scripts/integrate-no-kprobe.py" "$DEFCONFIG_PATH" $EXTRA_PYTHON_ARGS
        # echo "[+] Python patch script executed successfully."
    else
        # Download the script if it doesn't exist in the submodule
        echo "[+] Script not found in submodule, downloading..."
        TEMP_SCRIPT="$KERNEL_DIR/KernelSU/scripts/integrate-no-kprobe.py"
        curl -LSs "https://raw.githubusercontent.com/mlm-games/KernelSU-Non-GKI/refs/heads/main/scripts/integrate-no-kprobe.py" -o "$TEMP_SCRIPT"
        # if curl -LSs "https://raw.githubusercontent.com/mlm-games/KernelSU-Non-GKI/refs/heads/main/scripts/integrate-no-kprobe.py" -o "$TEMP_SCRIPT"; then
            # python3 "$TEMP_SCRIPT" "$DEFCONFIG_PATH" $EXTRA_PYTHON_ARGS
            # rm -f "$TEMP_SCRIPT"
            # echo "[+] Python patch script executed successfully."
        # else
            # echo "[ERROR] Failed to download the Python script." >&2
            # rm -f "$TEMP_SCRIPT"
            # exit 1
        # fi
    fi

    # Add the ksu_hook.h to include folder
    if [ -f "$KERNEL_DIR/KernelSU/kernel/include/ksu_hook.h" ]; then
        cp "$KERNEL_DIR/KernelSU/kernel/include/ksu_hook.h" "$KERNEL_DIR/include/ksu_hook.h"
        echo "[+] Added ksu_hook.h to include."
    fi

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
      echo "[WARNING] Unknown argument: $arg"
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
