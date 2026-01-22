#!/bin/bash

# --- CONFIGURATION (Adjust UE_ROOT to your mount point) ---
PYTHON_VER="3.12"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
ROCM_PATH="/opt/rocm"

# Exit on any error
set -e

echo "Starting Unified Unreal Engine 5.7 ROCm/Python Setup..."

# 1. Install System Dependencies (Replaces install_python312_headers logic)
echo "[1/4] Installing Python $PYTHON_VER dev headers and Boost..."
sudo apt update
sudo apt install -y python${PYTHON_VER}-dev libpython${PYTHON_VER}-dev libboost-python-dev

# 2. Prepare UE Directory Structure
echo "[2/4] Preparing UE ThirdParty directories..."
sudo chmod -R 777 "$UE_ROOT"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/include"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib"

# 3. Create Library & Header Symlinks (The "Linux Port" of your PS1 logic)
# This forces UE to use your 3.12 headers instead of its default versions
echo "[3/4] Overwriting UE ThirdParty links with Python $PYTHON_VER..."

# Link Python Static Lib
sudo ln -sf /usr/lib/python${PYTHON_VER}/config-${PYTHON_VER}-x86_64-linux-gnu/libpython${PYTHON_VER}.a \
    "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib/libpython${PYTHON_VER}.a"

# Link Python Headers (Crucial for the 'missing header' errors)
# This maps /usr/include/python3.12 to the path UE expects
sudo ln -sf /usr/include/python${PYTHON_VER} "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/include/python${PYTHON_VER}"

# Link Boost Python Static Lib (Matches your repo's requirement for Boost integration)
BOOST_LIB=$(find /usr/lib/x86_64-linux-gnu/ -name "libboost_python312*.a" | head -n 1)
if [ -n "$BOOST_LIB" ]; then
    sudo ln -sf "$BOOST_LIB" \
        "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib/libboost_python312-mt-x64.a"
fi

# 4. Set Environment Variables (Replaces Setup-ROCm.ps1 logic)
echo "[4/4] Configuring ROCm and Python environment..."
export UE_PYTHON_DIR="/usr"
export ROCM_PATH="$ROCM_PATH"
export HIP_PATH="$ROCM_PATH/hip"
export LD_LIBRARY_PATH="$ROCM_PATH/lib:$LD_LIBRARY_PATH"
export PATH="$ROCM_PATH/bin:$PATH"

echo "-----------------------------------------------------------"
echo "SETUP COMPLETE!"
echo "Python $PYTHON_VER is now linked to UE 5.7 ThirdParty."
echo "ROCm Path: $ROCM_PATH"
echo "-----------------------------------------------------------"
echo "Next: run './GenerateProjectFiles.sh' in $UE_ROOT"
