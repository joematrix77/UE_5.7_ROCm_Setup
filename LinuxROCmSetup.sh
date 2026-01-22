#!/bin/bash

# --- CONFIGURATION ---
PYTHON_VER="3.12"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
ROCM_PATH="/opt/rocm"

# Exit on any error
set -e

echo "Starting Unified Unreal Engine 5.7 ROCm/Python Setup..."

# 1. Install System Dependencies & Headers
echo "[1/4] Installing Python $PYTHON_VER dev headers and Boost..."
sudo apt update
# Use the generic 'libboost-python-dev' which maps to version 1.83 on Ubuntu 24.04
sudo apt install -y python${PYTHON_VER}-dev libpython${PYTHON_VER}-dev libboost-python-dev

# 2. Fix Directory Permissions & Structure
echo "[2/4] Setting permissions for $UE_ROOT..."
sudo chmod -R 777 "$UE_ROOT"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/include"
# Note: UE 5.7 expects a folder named after boost-1.85.0; we will place our links there.
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib"

# 3. Create Library Symlinks
echo "[3/4] Linking system libraries to UE ThirdParty..."
# Link Python 3.12 Static Lib
sudo ln -sf /usr/lib/python${PYTHON_VER}/config-${PYTHON_VER}-x86_64-linux-gnu/libpython${PYTHON_VER}.a \
    "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib/libpython${PYTHON_VER}.a"

# Dynamically find the Boost Python static library (works for 1.83 or 1.85)
BOOST_LIB=$(find /usr/lib/x86_64-linux-gnu/ -name "libboost_python312*.a" | head -n 1)
if [ -z "$BOOST_LIB" ]; then
    echo "Error: libboost_python312 static library not found!"
    exit 1
fi

sudo ln -sf "$BOOST_LIB" \
    "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib/libboost_python312-mt-x64.a"

# Link Python Headers
sudo ln -sf /usr/include/python${PYTHON_VER} "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/include/python${PYTHON_VER}"

# 4. Set Environment Variables
echo "[4/4] Configuring ROCm and Python environment..."
export UE_PYTHON_DIR="/usr"
export ROCM_PATH="$ROCM_PATH"
export HIP_PATH="$ROCM_PATH/hip"
export LD_LIBRARY_PATH="$ROCM_PATH/lib:$LD_LIBRARY_PATH"
export PATH="$ROCM_PATH/bin:$PATH"

echo "-----------------------------------------------------------"
echo "SETUP COMPLETE!"
echo "Python Version: $(python${PYTHON_VER} --version)"
echo "Boost Library linked: $BOOST_LIB"
echo "-----------------------------------------------------------"
echo "Next step: Run './GenerateProjectFiles.sh' in your UE folder."
