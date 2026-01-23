#!/usr/bin/env bash
set -euo pipefail

#############################################
# Linux ROCm 7.2 + UE Python 3.12 Setup
# Verified for Jan 2026 (Ubuntu 24.04 "Noble")
#############################################

UE_PATH="/media/joematrix/Storage/UE_5.7"
INTERNAL_PYTHON="$UE_PATH/Engine/Binaries/ThirdParty/Python3/Linux"
TEMP_DIR="/tmp/ue_python_setup"

echo "========================================"
echo "Starting UE Python 3.12 + ROCm 7.2 setup"
echo "========================================"

#############################################
# 1) Install System Dependencies
#############################################
echo "--- Installing system build dependencies ---"
sudo apt update
# Note: Use libncurses-dev (standard in 24.04)
sudo apt install -y build-essential wget curl xz-utils \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncurses-dev \
    tk-dev liblzma-dev pkg-config git \
    python3.12-dev python3.12-venv python3-pip

#############################################
# 2) Download and Install Internal Python 3.12
#############################################
echo "--- Downloading Python 3.12.8 Source ---"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR" && cd "$TEMP_DIR"

PYTHON_VER="3.12.8"
# Direct link to the source archive
PYTHON_URL="https://www.python.org"

wget "$PYTHON_URL" -O "Python-$PYTHON_VER.tar.xz"

if [[ ! -f "Python-$PYTHON_VER.tar.xz" ]]; then
    echo "ERROR: Download failed!"
    exit 1
fi

echo "--- Extracting and Building ---"
tar -xf "Python-$PYTHON_VER.tar.xz"
cd "Python-$PYTHON_VER"

./configure --prefix="$INTERNAL_PYTHON" --enable-shared --with-system-ffi \
    CFLAGS="-fPIC" LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"
make -j"$(nproc)"
sudo make install

# Symlink shared libs for UE
cd "$INTERNAL_PYTHON/lib"
sudo ln -sf libpython3.12.so.1.0 libpython3.12.so

#############################################
# 3) ROCm 7.2 Repository Setup
#############################################
echo "--- Configuring ROCm 7.2 for Noble ---"
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://repo.radeon.com | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rocm.list << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.2 noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/7.2/ubuntu noble main
EOF

sudo apt update
sudo apt install -y rocm-dkms rocm-dev hipblas miopen-hip

#############################################
# 4) Environment Setup
#############################################
echo "--- Validating ROCm ---"
/opt/rocm/bin/rocminfo | grep gfx || echo "Warning: GPU not detected by ROCm."

cat << 'EOF'

========================================
To install PyTorch (ROCm 7.2 + Python 3.12):
========================================

    python3.12 -m venv ~/rocm_torch
    source ~/rocm_torch/bin/activate
    pip install --upgrade pip wheel
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm7.2

========================================
EOF
