#!/bin/bash
# Configuration
PYTHON_VER="3.12"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
INTERNAL_PY_PATH="$UE_ROOT/Engine/Binaries/ThirdParty/Python3/Linux"

set -e

echo "Starting internalized Python 3.12 setup for UE 5.7 (Linux)..."

# 1. Install necessary build dependencies on the host
sudo apt update && sudo apt install -y build-essential libssl-dev libffi-dev zlib1g-dev

# 2. Compile a portable Python into the UE folder
mkdir -p "$INTERNAL_PY_PATH"
TEMP_BUILD="/tmp/ue_python_build"
mkdir -p "$TEMP_BUILD" && cd "$TEMP_BUILD"

wget https://www.python.org
tar -xf Python-3.12.8.tar.xz && cd Python-3.12.8

# Configure to install directly into the Engine's ThirdParty folder
# --enable-shared and -fPIC are required for UE modules to link properly
./configure --prefix="$INTERNAL_PY_PATH" --enable-shared --with-system-ffi LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"
make -j$(nproc)
make install

# 3. Fix names for Unreal Build Tool (UBT)
cd "$INTERNAL_PY_PATH/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

# 4. Set the Engine variable to point internally
export UE_PYTHON_DIR="$INTERNAL_PY_PATH"

echo "-----------------------------------------------------------"
echo "Internal Python 3.12 is now installed at: $INTERNAL_PY_PATH"
echo "This mirrors your Windows setup logic."
echo "-----------------------------------------------------------"
