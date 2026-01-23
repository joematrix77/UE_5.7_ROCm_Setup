#!/usr/bin/env bash
set -euo pipefail

#############################################
# Linux ROCm + UE Python 3.12 Setup Script
# Updated for ROCm 7.2 (Ubuntu 24.04 "noble")
#############################################

UE_PATH="/media/joematrix/Storage/UE_5.7"
INTERNAL_PYTHON="$UE_PATH/Engine/Binaries/ThirdParty/Python3/Linux"
TEMP_DIR="/tmp/ue_python_setup"

echo "========================================"
echo "Starting UE Python 3.12 + ROCm 7.2 setup"
echo "UE Path: $UE_PATH"
echo "Internal Python Path: $INTERNAL_PYTHON"
echo "========================================"

#############################################
# 1) Install System Dependencies
#############################################
echo "--- Installing system build dependencies ---"
sudo apt update
sudo apt install -y build-essential wget curl xz-utils \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncursesw5-dev \
    tk-dev liblzma-dev pkg-config git python3.11 python3.11-venv python3-pip

#############################################
# 2) Download and Install Internal Python 3.12
#############################################
echo "--- Downloading Python 3.12 source ---"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR" && cd "$TEMP_DIR"

PYTHON_VER="3.12.8"
wget "https://www.python.org/ftp/python/$PYTHON_VER/Python-$PYTHON_VER.tar.xz"
tar -xf "Python-$PYTHON_VER.tar.xz"
cd "Python-$PYTHON_VER"

echo "--- Configuring and building Python ---"
./configure --prefix="$INTERNAL_PYTHON" --enable-shared --with-system-ffi \
    CFLAGS="-fPIC" LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"
make -j"$(nproc)" && make install

# Symlink shared libs for UE
cd "$INTERNAL_PYTHON/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

#############################################
# 3) Patch UE Build.cs
#############################################
PYTHON_BUILD_CS="$UE_PATH/Engine/Source/ThirdParty/Python3/Python3.Build.cs"
if [[ -f "$PYTHON_BUILD_CS" ]]; then
    echo "--- Patching Python3.Build.cs ---"
    sed -i "s/libpython3.12.a/libpython3.12.so/g" "$PYTHON_BUILD_CS"
    if ! grep -q "PublicAdditionalLibraries.Add(\"python3.12\")" "$PYTHON_BUILD_CS"; then
        sed -i "/PublicSystemLibraryPaths.Add/a\        PublicAdditionalLibraries.Add(\"python3.12\");" "$PYTHON_BUILD_CS"
    fi
fi

#############################################
# 4) ROCm 7.2 Install (Updated)
#############################################
echo "--- Installing ROCm 7.2 ---"
sudo usermod -a -G render,video "$USER"

# Modern keyring instead of apt-key
sudo mkdir --parents --mode=0755 /etc/apt/keyrings
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | \
    gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

# Register ROCm 7.2 repositories for Ubuntu 24.04 (noble)
sudo tee /etc/apt/sources.list.d/rocm.list << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.2 noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/7.2/ubuntu noble main
EOF

# Pin repo priority to avoid conflicts
sudo tee /etc/apt/preferences.d/rocm-pin-600 << EOF
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600
EOF

sudo apt update
sudo apt install -y rocm-dkms rocm-dev rocm-utils hipblas miopen-hip

# Add ROCm environment to user profile
if ! grep -q "/opt/rocm" ~/.bashrc; then
    cat >> ~/.bashrc <<EOF
export PATH=/opt/rocm/bin:\$PATH
export LD_LIBRARY_PATH=/opt/rocm/lib:\$LD_LIBRARY_PATH
EOF
fi

#############################################
# 5) ROCm GPU validation
#############################################
echo "--- ROCm GPU validation ---"
/opt/rocm/bin/rocminfo | grep gfx || echo "WARNING: No gfx targets found!"

#############################################
# 6) PyTorch Note (Optional)
#############################################
cat << 'EOF'

========================================
PyTorch ROCm 7.2 installation:
========================================
Use a separate Python environment to install PyTorch if needed.
Do NOT install into UE Python 3.12 to avoid compatibility issues.

Example:
    python3.11 -m venv ~/rocm_torch
    source ~/rocm_torch/bin/activate
    pip install --upgrade pip wheel
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm7.2

EOF

echo "========================================"
echo "Linux ROCm + UE Python 3.12 setup complete!"
echo "Build UE and continue with your normal workflow."
echo "========================================"
