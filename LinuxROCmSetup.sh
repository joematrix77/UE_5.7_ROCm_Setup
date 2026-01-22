#!/bin/bash

# --- CONFIGURATION ---
PYTHON_VER="3.12"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
ROCM_PATH="/opt/rocm"

# Exit on any error
set -e

echo "Starting Unified Unreal Engine 5.7 ROCm/Python Setup for Linux..."

# 1. Install System Dependencies
echo "[1/4] Installing Python $PYTHON_VER dev headers and generic Boost..."
sudo apt update
# Use generic packages available in Ubuntu 24.04
sudo apt install -y python${PYTHON_VER}-dev libpython${PYTHON_VER}-dev libboost-python-dev

# 2. Prepare UE Directory Structure
echo "[2/4] Preparing UE ThirdParty directories..."
sudo chmod -R 777 "$UE_ROOT"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/include"
# UE 5.7 specifically looks for this 1.85.0 folder path
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib"

# 3. Create Library & Header Symlinks (Port of your .ps1 logic)
echo "[3/4] Overwriting UE ThirdParty links with Python $PYTHON_VER..."

# Link Python Static Lib (Found in config directory)
sudo ln -sf /usr/lib/python${PYTHON_VER}/config-${PYTHON_VER}-x86_64-linux-gnu/libpython${PYTHON_VER}.a \
    "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib/libpython${PYTHON_VER}.a"

# Link Python Headers (Forces UE to use system 3.12 headers)
sudo ln -sf /usr/include/python${PYTHON_VER} "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/include/python${PYTHON_VER}"

# Link Boost Python Static Lib (Dynamically find the 1.83 version and link it as 1.85)
BOOST_LIB=$(find /usr/lib/x86_64-linux-gnu/ -name "libboost_python312*.a" | head -n 1)
if [ -z "$BOOST_LIB" ]; then
    echo "Error: libboost_python312 static library not found! Ensure libboost-python-dev is installed."
    exit 1
fi
sudo ln -sf "$BOOST_LIB" \
    "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib/libboost_python312-mt-x64.a"

# 4. Set Environment Variables
echo "[4/4] Configuring ROCm and Python environment..."
export UE_PYTHON_DIR="/usr"
export ROCM_PATH="$ROCM_PATH"
export HIP_PATH="$ROCM_PATH/hip"
export LD_LIBRARY_PATH="$ROCM_PATH/lib:$LD_LIBRARY_PATH"
export PATH="$ROCM_PATH/bin:$PATH"

echo "-----------------------------------------------------------"
echo "SETUP COMPLETE!"
echo "Linked $BOOST_LIB -> UE Boost 1.85 path"
echo "ROCm Path: $ROCM_PATH"
echo "-----------------------------------------------------------"
echo "Next: run './GenerateProjectFiles.sh' in $UE_ROOT"
