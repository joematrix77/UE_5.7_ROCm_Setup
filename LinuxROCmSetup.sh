#!/bin/bash
# Port of Setup-ROCm.ps1 logic for internalized UE 5.7 Python on Linux (2026)
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

# 1. Install system-level build tools (only needed once for compilation)
sudo apt update && sudo apt install -y \
    build-essential libssl-dev libffi-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl \
    libncursesw5-dev xz-utils tk-dev liblzma-dev

# 2. Download and Extract Python Source
rm -rf "$TEMP_BUILD"
mkdir -p "$TEMP_BUILD" && cd "$TEMP_BUILD"
echo "Downloading Python $PYTHON_VER source..."
wget "https://www.python.org{PYTHON_VER}/Python-${PYTHON_VER}.tar.xz"
tar -xf "Python-${PYTHON_VER}.tar.xz" && cd "Python-${PYTHON_VER}"

# 3. Configure & Build specifically for the internal folder
# CFLAGS="-fPIC" is mandatory to prevent previous "relocation" linker errors
echo "Configuring internalized build with -fPIC..."
./configure --prefix="$INTERNAL_PATH" \
            --enable-shared \
            --with-system-ffi \
            CFLAGS="-fPIC" \
            LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"

echo "Building (this may take 5-10 minutes)..."
make -j$(nproc)
make install

# 4. Fix Library Naming for Unreal Build Tool (UBT) compatibility
# Linux UBT expects specific names; we create symlinks to match
cd "$INTERNAL_PATH/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

# 5. Patch Engine Source (The "LNK1104" equivalent fix for Linux)
# This forces the build tool to look for the .so library instead of .a
PYTHON_BUILD_CS="$UE_ROOT/Engine/Source/ThirdParty/Python3/Python3.Build.cs"
if [ -f "$PYTHON_BUILD_CS" ]; then
    echo "Patching Python3.Build.cs for shared library visibility..."
    sed -i "s/libpython3.12.a/libpython3.12.so/g" "$PYTHON_BUILD_CS"
    # Ensure PublicAdditionalLibraries includes the global python name
    if ! grep -q "PublicAdditionalLibraries.Add(\"python3.12\")" "$PYTHON_BUILD_CS"; then
        sed -i "/PublicSystemLibraryPaths.Add/a \ \ \ \ \ \ \ \ PublicAdditionalLibraries.Add(\"python3.12\");" "$PYTHON_BUILD_CS"
    fi
fi

# 6. Set Environment for ROCm integration
export UE_PYTHON_DIR="$INTERNAL_PATH"
# Ensure your user has GPU hardware access
sudo usermod -a -G render,video $USER

echo "-----------------------------------------------------------"
echo "INTERNAL SETUP SUCCESSFUL"
echo "-----------------------------------------------------------"
echo "Next steps to complete build:"
echo "1. rm -rf $UE_ROOT/Engine/Intermediate/Build/Linux"
echo "2. cd $UE_ROOT"
echo "3. ./GenerateProjectFiles.sh"
echo "4. make"
