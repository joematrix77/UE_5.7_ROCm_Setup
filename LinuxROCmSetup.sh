#!/bin/bash

# --- CONFIGURATION ---
PYTHON_VER="3.12"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
ROCM_PATH="/opt/rocm"

set -e

echo "Applying Final Python Symbol Fix for UE 5.7..."

# 1. Install Dev Packages
sudo apt update && sudo apt install -y python${PYTHON_VER}-dev libpython${PYTHON_VER}-dev libboost-python-dev

# 2. Setup Directories
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib"
mkdir -p "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib"

# 3. Create BOTH .so and .a symlinks (some modules look for one, some for the other)
# We point BOTH to the shared library to ensure -fPIC compatibility
sudo ln -sf /usr/lib/x86_64-linux-gnu/libpython${PYTHON_VER}.so \
    "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib/libpython${PYTHON_VER}.so"
sudo ln -sf /usr/lib/x86_64-linux-gnu/libpython${PYTHON_VER}.so \
    "$UE_ROOT/Engine/Source/ThirdParty/Python3/Linux/lib/libpython${PYTHON_VER}.a"

# Boost Symlinks
BOOST_SO=$(find /usr/lib/x86_64-linux-gnu/ -name "libboost_python312*.so" | head -n 1)
sudo ln -sf "$BOOST_SO" \
    "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib/libboost_python312-mt-x64.so"
sudo ln -sf "$BOOST_SO" \
    "$UE_ROOT/Engine/Source/ThirdParty/Boost/Deploy/boost-1.85.0/Unix/x86_64-unknown-linux-gnu/lib/libboost_python312-mt-x64.a"

# 4. FORCE LINKER FLAG in Build.cs
# This is the "Magic Bullet": It tells the compiler to explicitly link python
PYTHON_BUILD_CS="$UE_ROOT/Engine/Source/ThirdParty/Python3/Python3.Build.cs"
if [ -f "$PYTHON_BUILD_CS" ]; then
    echo "Patching Python3.Build.cs to force linker visibility..."
    # We add a line to ensure the library is added to PublicAdditionalLibraries
    sed -i "/PublicSystemLibraryPaths.Add/a \ \ \ \ \ \ \ \ PublicAdditionalLibraries.Add(\"python${PYTHON_VER}\");" "$PYTHON_BUILD_CS"
fi

# 5. Refresh Environment
export UE_PYTHON_DIR="/usr"
export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"

echo "-----------------------------------------------------------"
echo "Fix Applied. CRITICAL: You must delete your Intermediate folders now."
echo "Run: rm -rf $UE_ROOT/Engine/Intermediate/Build/Linux"
echo "Then: ./GenerateProjectFiles.sh && make"
echo "-----------------------------------------------------------"
