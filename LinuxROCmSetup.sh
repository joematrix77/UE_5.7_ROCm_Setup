#!/bin/bash

# 1. Configuration
PYTHON_VER="3.12"
# In Ubuntu, Python 3.12 is typically at /usr/bin/python3.12
# For UE source builds, point to the directory containing 'bin' and 'include'
PYTHON_ROOT_DIR="/usr"

# 2. Check if Python 3.12 is installed
if ! command -v python$PYTHON_VER &> /dev/null; then
    echo "Python $PYTHON_VER not found. Installing..."
    sudo apt update && sudo apt install -y python$PYTHON_VER python$PYTHON_VER-dev python$PYTHON_VER-venv
fi

# 3. Set Unreal Engine Environment Variables
# UE_PYTHON_DIR tells the build system which Python to embed
export UE_PYTHON_DIR=$PYTHON_ROOT_DIR
export UE_PYTHONPATH="/usr/lib/python$PYTHON_VER"

# 4. ROCm Environment Variables (Standard for ROCm 6.x in 2026)
export ROCM_PATH=/opt/rocm
export HIP_PATH=$ROCM_PATH/hip
export LD_LIBRARY_PATH=$ROCM_PATH/lib:$LD_LIBRARY_PATH
export PATH=$ROCM_PATH/bin:$PATH

# 5. Fix permissions for your storage mount (per your earlier error)
# Adjust the path to match your specific UE location
UE_ROOT="/media/joematrix/Storage/UE_5.7"
if [ -d "$UE_ROOT" ]; then
    echo "Setting permissions for $UE_ROOT..."
    sudo chmod -R 777 "$UE_ROOT"
fi

echo "Environment ready for UE 5.7 with ROCm and Python $PYTHON_VER"
echo "To apply: run './GenerateProjectFiles.sh' then 'make'"
