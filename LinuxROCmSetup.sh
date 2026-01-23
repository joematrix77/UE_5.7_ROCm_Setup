#!/bin/bash
set -e

# --- CONFIGURATION ---
UE_ROOT="/media/joematrix/Storage/UE_5.7"
INTERNAL_PATH="$UE_ROOT/Engine/Binaries/ThirdParty/Python3/Linux"
TEMP_BUILD="/tmp/ue_python_build_final"

echo "Starting internalized Python 3.12.8 setup for UE 5.7..."

# 1. INSTALL SYSTEM BUILD TOOLS
sudo apt update && sudo apt install -y \
    build-essential libssl-dev libffi-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl \
    libncursesw5-dev xz-utils tk-dev liblzma-dev

# 2. DOWNLOAD PYTHON SOURCE (Hardcoded URL to prevent variable errors)
rm -rf "$TEMP_BUILD"
mkdir -p "$TEMP_BUILD" && cd "$TEMP_BUILD"
echo "Downloading Python 3.12.8..."
wget https://www.python.org

echo "Extracting..."
tar -xf Python-3.12.8.tar.xz
cd Python-3.12.8

# 3. CONFIGURE & BUILD 
# -fPIC is mandatory for Linux shared modules in Unreal
echo "Configuring build for Unreal Engine..."
./configure --prefix="$INTERNAL_PATH" \
            --enable-shared \
            --with-system-ffi \
            CFLAGS="-fPIC" \
            LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"

echo "Building (using all CPU cores)..."
make -j$(nproc)
make install

# 4. FIX LIBRARY NAMING FOR UNREAL BUILD TOOL
cd "$INTERNAL_PATH/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

# 5. PATCH ENGINE SOURCE
# This ensures USD and Python plugins look for the .so we just built
PYTHON_BUILD_CS="$UE_ROOT/Engine/Source/ThirdParty/Python3/Python3.Build.cs"
if [ -f "$PYTHON_BUILD_CS" ]; then
    echo "Patching Python3.Build.cs..."
    sed -i "s/libpython3.12.a/libpython3.12.so/g" "$PYTHON_BUILD_CS"
    # Force visibility of the library to all modules
    if ! grep -q "PublicAdditionalLibraries.Add(\"python3.12\")" "$PYTHON_BUILD_CS"; then
        sed -i "/PublicSystemLibraryPaths.Add/a \ \ \ \ \ \ \ \ PublicAdditionalLibraries.Add(\"python3.12\");" "$PYTHON_BUILD_CS"
    fi
fi

# 6. SET ENVIRONMENT FOR ROCm
export UE_PYTHON_DIR="$INTERNAL_PATH"
sudo usermod -a -G render,video $USER

echo "-----------------------------------------------------------"
echo "INTERNAL SETUP SUCCESSFUL"
echo "-----------------------------------------------------------"
echo "FINAL COMMANDS TO RUN:"
echo "1. rm -rf $UE_ROOT/Engine/Intermediate/Build/Linux"
echo "2. cd $UE_ROOT"
echo "3. ./GenerateProjectFiles.sh"
echo "4. make"
