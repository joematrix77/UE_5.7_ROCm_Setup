#!/bin/bash

# --- CONFIGURATION ---
PYTHON_VER="3.12"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
ROCM_PATH="/opt/rocm"

# Exit on any error
set -e

echo "Starting Unified Unreal Engine 5.7 ROCm/Python Setup (Shared Lib Fix)..."

# 1. Install System Dependencies
echo "[1/4] Installing Python $PYTHON_VER dev headers and Boost..."
sudo apt update
sudo apt install -y python${PYTHON_VER}-dev libpython${PYTHON_VER}-dev libboost-python-dev

# 2. Prepare UE Directory Structure
echo "[2/4] Preparing UE ThirdParty directories..."
sudo chmod -R 777 "$UE_ROOT"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/include"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib"

# 3. Create Library & Header Symlinks (Using .so to avoid -fPIC errors)
echo "[3/4] Linking shared libraries to UE ThirdParty..."

# Link Python Shared Lib (Correct way for Linux)
sudo ln -sf /usr/lib/x86_64-linux-gnu/libpython${PYTHON_VER}.so \
    "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib/libpython${PYTHON_VER}.so"

# Link Python Headers
sudo ln -sf /usr/include/python${PYTHON_VER} "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/include/python${PYTHON_VER}"

# Link Boost Python Shared Lib
BOOST_SO=$(find /usr/lib/x86_64-linux-gnu/ -name "libboost_python312*.so" | head -n 1)
sudo ln -sf "$BOOST_SO" \
    "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib/libboost_python312-mt-x64.so"

# 4. Patch Unreal Engine Build Script (Crucial Step)
# This forces UBT to look for .so instead of .a
echo "[4/4] Patching Python3.Build.cs to use Shared Libraries..."
PYTHON_BUILD_CS="$UE_ROOT/Engine/Source/ThirdParty/Python3/Python3.Build.cs"
if [ -f "$PYTHON_BUILD_CS" ]; then
    # Replace libpython3.12.a with libpython3.12.so in the build config
    sed -i "s/libpython${PYTHON_VER}.a/libpython${PYTHON_VER}.so/g" "$PYTHON_BUILD_CS"
    # Also patch Boost if needed
    BOOST_BUILD_CS="$UE_ROOT/Engine/Source/ThirdParty/Boost/Boost.Build.cs"
    if [ -f "$BOOST_BUILD_CS" ]; then
        sed -i "s/libboost_python312-mt-x64.a/libboost_python312-mt-x64.so/g" "$BOOST_BUILD_CS"
    fi
fi

# 5. Environment Variables
export UE_PYTHON_DIR="/usr"
export ROCM_PATH="$ROCM_PATH"
export HIP_PATH="$ROCM_PATH/hip"
export LD_LIBRARY_PATH="$ROCM_PATH/lib:$LD_LIBRARY_PATH"
export PATH="$ROCM_PATH/bin:$PATH"

echo "-----------------------------------------------------------"
echo "SETUP COMPLETE!"
echo "Next: Run './GenerateProjectFiles.sh' and then 'make'"
echo "-----------------------------------------------------------"
