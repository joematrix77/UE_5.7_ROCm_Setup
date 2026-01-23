#!/bin/bash
# Configuration
PYTHON_VER="3.12.8"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
INTERNAL_PY_PATH="$UE_ROOT/Engine/Binaries/ThirdParty/Python3/Linux"

set -e

echo "Starting internalized Python $PYTHON_VER setup for UE 5.7 (Linux)..."

# 1. Install necessary build dependencies on the host
# Added extra libs for a complete Python build (ssl, bz2, readline, etc)
sudo apt update && sudo apt install -y build-essential libssl-dev libffi-dev \
    zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev

# 2. Compile a portable Python into the UE folder
mkdir -p "$INTERNAL_PY_PATH"
TEMP_BUILD="/tmp/ue_python_build"
rm -rf "$TEMP_BUILD"  # Clean previous failed attempts
mkdir -p "$TEMP_BUILD" && cd "$TEMP_BUILD"

# CORRECTED DOWNLOAD URL
echo "Downloading Python $PYTHON_VER source..."
wget "https://www.python.org{PYTHON_VER}/Python-${PYTHON_VER}.tar.xz"

echo "Extracting..."
tar -xf "Python-${PYTHON_VER}.tar.xz" && cd "Python-${PYTHON_VER}"

# 3. Configure and Build
# --enable-shared and -fPIC are required for UE modules to link properly
echo "Configuring Python..."
./configure --prefix="$INTERNAL_PY_PATH" \
            --enable-shared \
            --with-system-ffi \
            LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"

echo "Building (this may take a few minutes)..."
make -j$(nproc)
echo "Installing into $INTERNAL_PY_PATH..."
make install

# 4. Fix names for Unreal Build Tool (UBT) compatibility
cd "$INTERNAL_PY_PATH/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

# 5. Final Setup for ROCm Environment Variables
export UE_PYTHON_DIR="$INTERNAL_PY_PATH"
export ROCM_PATH="/opt/rocm"
export HIP_PATH="$ROCM_PATH/hip"
export LD_LIBRARY_PATH="$INTERNAL_PY_PATH/lib:$ROCM_PATH/lib:$LD_LIBRARY_PATH"

echo "-----------------------------------------------------------"
echo "Internal Python 3.12 is now installed at: $INTERNAL_PY_PATH"
echo "-----------------------------------------------------------"
echo "CRITICAL: Run these commands next:"
echo "1. rm -rf $UE_ROOT/Engine/Intermediate/Build/Linux"
echo "2. cd $UE_ROOT"
echo "3. ./GenerateProjectFiles.sh"
echo "4. make"
