#!/bin/bash
# Configuration for 2026
PYTHON_VER="3.12.8"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
INTERNAL_PY_PATH="$UE_ROOT/Engine/Binaries/ThirdParty/Python3/Linux"

set -e

echo "Starting internalized Python $PYTHON_VER setup for UE 5.7 (2026)..."

# 1. Install system build dependencies
sudo apt update && sudo apt install -y build-essential libssl-dev libffi-dev \
    zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev liblzma-dev

# 2. Prepare build directory
mkdir -p "$INTERNAL_PY_PATH"
TEMP_BUILD="/tmp/ue_python_build_2026"
rm -rf "$TEMP_BUILD" 
mkdir -p "$TEMP_BUILD" && cd "$TEMP_BUILD"

# 3. DIRECT DOWNLOAD (Fixed URL for 2026)
echo "Downloading Python $PYTHON_VER source code..."
wget "{PYTHON_VER}/Python-${PYTHON_VER}.tar.xz"

echo "Extracting..."
tar -xf "Python-${PYTHON_VER}.tar.xz"
cd "Python-${PYTHON_VER}"

# 4. Configure and Build with UE-Required Flags
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

# 6. Set Environment Variables
export UE_PYTHON_DIR="$INTERNAL_PY_PATH"
export ROCM_PATH="/opt/rocm"
export PATH="$INTERNAL_PY_PATH/bin:$ROCM_PATH/bin:$PATH"
export LD_LIBRARY_PATH="$INTERNAL_PY_PATH/lib:$ROCM_PATH/lib:$LD_LIBRARY_PATH"

echo "-----------------------------------------------------------"
echo "INTERNAL PYTHON SETUP COMPLETE"
echo "-----------------------------------------------------------"
