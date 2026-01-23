#!/bin/bash
# Port of install_python312_headers.ps1 for Ubuntu 24.04 / UE 5.7
set -e

# --- CONFIGURATION ---
UE_PATH="/media/joematrix/Storage/UE_5.7"
PYTHON_VER="3.12.8"
TEMP_DIR="/tmp/python312_setup"
TARGET_DIR="$UE_PATH/Engine/Source/ThirdParty/Python3/Linux"

echo "========================================"
echo "Installing Python 3.12 Headers & Libs (Linux)"
echo "========================================"

# 1. Install system dependencies needed to extract/run
sudo apt update && sudo apt install -y wget xz-utils tar

# 2. Download Python Source (Equivalent to NuGet download)
mkdir -p "$TEMP_DIR" && cd "$TEMP_DIR"
if [ ! -f "python.tar.xz" ]; then
    echo "Downloading Python $PYTHON_VER source..."
    wget -O python.tar.xz "https://www.python.org"
fi

# 3. Extract Headers
echo "Extracting headers..."
tar -xf python.tar.xz
SOURCE_INCLUDE="Python-$PYTHON_VER/Include"

# 4. Backup Existing UE Headers
BACKUP_SUFFIX=$(date +%Y%m%d_%H%M%S)
if [ -d "$TARGET_DIR/include" ]; then
    echo "Backing up existing headers..."
    mv "$TARGET_DIR/include" "${TARGET_DIR}/include_backup_${BACKUP_SUFFIX}"
fi

# 5. Copy New Headers to UE Linux ThirdParty
echo "Installing Python 3.12 headers to Linux..."
mkdir -p "$TARGET_DIR/include"
cp -r $SOURCE_INCLUDE/* "$TARGET_DIR/include/"
# Linux also requires the pyconfig.h generated at build time
# We link the system one as a fallback for the headers to be valid
cp /usr/include/python3.12/pyconfig.h "$TARGET_DIR/include/" 2>/dev/null || echo "Note: system pyconfig.h not found, ensure python3.12-dev is installed."

# 6. Create Symlinks for Library (The Linux equivalent of the .lib fix)
echo "Setting up library references..."
mkdir -p "$TARGET_DIR/lib"
# Points the internal UE folder to the system shared object to solve linker errors
sudo ln -sf /usr/lib/x86_64-linux-gnu/libpython3.12.so "$TARGET_DIR/lib/libpython3.12.so"
sudo ln -sf /usr/lib/x86_64-linux-gnu/libpython3.12.so "$TARGET_DIR/lib/libpython3.12.a"

# 7. Verification
echo ""
echo "========================================"
echo "Verification"
echo "========================================"
if [ -f "$TARGET_DIR/include/patchlevel.h" ]; then
    VERSION=$(grep "PY_VERSION " "$TARGET_DIR/include/patchlevel.h" | cut -d'"' -f2)
    echo "Python version in headers: $VERSION"
fi

echo "Done! Python 3.12 headers installed for Linux."
echo "Next: rm -rf $UE_PATH/Engine/Intermediate/Build/Linux && ./GenerateProjectFiles.sh"
