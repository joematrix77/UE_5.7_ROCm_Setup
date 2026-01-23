#!/bin/bash
# Configuration
PYTHON_VER="3.12.8"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
INTERNAL_PY_PATH="$UE_ROOT/Engine/Binaries/ThirdParty/Python3/Linux"

set -e

echo "Starting internalized Python $PYTHON_VER setup for UE 5.7 (Linux)..."

# 1. Install system-wide build tools required for the initial compilation
sudo apt update && sudo apt install -y build-essential libssl-dev libffi-dev \
    zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev

# 2. Prepare build directory
mkdir -p "$INTERNAL_PY_PATH"
TEMP_BUILD="/tmp/ue_python_build"
rm -rf "$TEMP_BUILD" 
mkdir -p "$TEMP_BUILD" && cd "$TEMP_BUILD"

# 3. Robust Download: Using a direct FTP link to the archive
echo "Downloading Python $PYTHON_VER source code..."
wget -O "Python-${PYTHON_VER}.tar.xz" "https://www.python.org{PYTHON_VER}/Python-${PYTHON_VER}.tar.xz"

echo "Extracting..."
tar -xf "Python-${PYTHON_VER}.tar.xz"
cd "Python-${PYTHON_VER}"

# 4. Configure and Build
# CRITICAL: --enable-shared and -fPIC ensure it works with UE plugins
echo "Configuring build for UE internal path..."
./configure --prefix="$INTERNAL_PY_PATH" \
            --enable-shared \
            --with-system-ffi \
            CFLAGS="-fPIC" \
            LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"

echo "Building (using all CPU cores)..."
make -j$(nproc)
echo "Installing into $INTERNAL_PY_PATH..."
make install

# 5. Fix library naming for Unreal Build Tool (UBT) compatibility
cd "$INTERNAL_PY_PATH/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

# 6. Set ROCm and Internal Python Environment
export UE_PYTHON_DIR="$INTERNAL_PY_PATH"
export ROCM_PATH="/opt/rocm"
export HIP_PATH="$ROCM_PATH/hip"
export LD_LIBRARY_PATH="$INTERNAL_PY_PATH/lib:$ROCM_PATH/lib:$LD_LIBRARY_PATH"

echo "-----------------------------------------------------------"
echo "INTERNAL PYTHON SETUP COMPLETE"
echo "Path: $INTERNAL_PY_PATH"
echo "-----------------------------------------------------------"
echo "Next: Clean intermediates and rebuild UE"
