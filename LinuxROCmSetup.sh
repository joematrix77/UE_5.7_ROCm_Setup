#!/bin/bash
# Replicates internalized Python logic for UE 5.7 Linux (Ubuntu 24.04)
set -e

# --- CONFIGURATION ---
PYTHON_VER="3.12.8"
UE_ROOT="/media/joematrix/Storage/UE_5.7"
INTERNAL_PATH="$UE_ROOT/Engine/Binaries/ThirdParty/Python3/Linux"
TEMP_BUILD="/tmp/ue_python_build_final"

echo "========================================"
echo "Starting Internalized Python $PYTHON_VER Setup"
echo "Target: $INTERNAL_PATH"
echo "========================================"

# 1. Install system build dependencies (Required for the compilation phase)
sudo apt update && sudo apt install -y \
    build-essential libssl-dev libffi-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl \
    libncursesw5-dev xz-utils tk-dev liblzma-dev

# 2. Download and Extract Verified Python Source
rm -rf "$TEMP_BUILD"
mkdir -p "$TEMP_BUILD" && cd "$TEMP_BUILD"
echo "Downloading verified Python 3.12.8 source..."
wget https://www.python.org/ftp/python/3.12.8/Python-3.12.8.tar.xz
tar -xf Python-3.12.8.tar.xz && cd Python-3.12.8

# 3. Configure & Build specifically for the internal folder
# CFLAGS="-fPIC" is mandatory for shared modules in Unreal Engine
echo "Configuring build with -fPIC and --enable-shared..."
./configure --prefix="$INTERNAL_PATH" \
            --enable-shared \
            --with-system-ffi \
            CFLAGS="-fPIC" \
            LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"

echo "Building (using all CPU cores)..."
make -j$(nproc)
make install

# 4. Fix Library Naming for Unreal Build Tool (UBT) compatibility
cd "$INTERNAL_PATH/lib"
# Links the shared object to names UBT expects
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

# 5. Patch Engine Source (Forces UBT to recognize the new library)
PYTHON_BUILD_CS="$UE_ROOT/Engine/Source/ThirdParty/Python3/Python3.Build.cs"
if [ -f "$PYTHON_BUILD_CS" ]; then
    echo "Patching Python3.Build.cs for Linux shared library usage..."
    sed -i "s/libpython3.12.a/libpython3.12.so/g" "$PYTHON_BUILD_CS"
    if ! grep -q "PublicAdditionalLibraries.Add(\"python3.12\")" "$PYTHON_BUILD_CS"; then
        sed -i "/PublicSystemLibraryPaths.Add/a \ \ \ \ \ \ \ \ PublicAdditionalLibraries.Add(\"python3.12\");" "$PYTHON_BUILD_CS"
    fi
fi

# 6. Configure Environment for ROCm integration
export UE_PYTHON_DIR="$INTERNAL_PATH"
# Grants necessary hardware permissions for AMD GPU [Step 1: Install AMD ROCm Drivers]
sudo usermod -a -G render,video $USER

echo "-----------------------------------------------------------"
echo "INTERNAL SETUP SUCCESSFUL"
echo "-----------------------------------------------------------"
echo "Final steps to build UE 5.7:"
echo "1. rm -rf $UE_ROOT/Engine/Intermediate/Build/Linux"
echo "2. cd $UE_ROOT"
echo "3. ./GenerateProjectFiles.sh && make"
