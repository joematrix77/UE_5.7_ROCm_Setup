#!/usr/bin/env bash
set -euo pipefail

#############################################
# Linux ROCm + UE Python 3.12 Setup Script
# Updated for 2026 (ROCm 7.2 on Ubuntu 24.04)
#############################################

UE_PATH="/media/joematrix/Storage/UE_5.7"
INTERNAL_PYTHON="$UE_PATH/Engine/Binaries/ThirdParty/Python3/Linux"
TEMP_DIR="/tmp/ue_python_setup"

echo "========================================"
echo "Starting UE Python 3.12 + ROCm 7.2 setup"
echo "UE Path: $UE_PATH"
echo "========================================"

#############################################
# 1) Install System Dependencies
# Fixed: Corrected venv package names for Ubuntu 24.04
#############################################
echo "--- Installing system build dependencies ---"
sudo apt update
sudo apt install -y build-essential wget curl xz-utils \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncurses-dev \
    tk-dev liblzma-dev pkg-config git \
    python3.12 python3.12-dev python3.12-venv python3-pip

#############################################
# 2) Download and Install Internal Python 3.12
#############################################
echo "--- Downloading and Building Python 3.12.8 ---"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR" && cd "$TEMP_DIR"

# Corrected direct download URL
PYTHON_VER="3.12.8"
PYTHON_TAR="Python-$PYTHON_VER.tar.xz"
wget "https://www.python.org"

if [[ ! -f "$PYTHON_TAR" ]]; then
    echo "ERROR: Failed to download $PYTHON_TAR"
    exit 1
fi

tar -xf "$PYTHON_TAR"
cd "Python-$PYTHON_VER"

echo "--- Configuring and building Python ---"
./configure --prefix="$INTERNAL_PYTHON" --enable-shared --with-system-ffi \
    CFLAGS="-fPIC" LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"
make -j"$(nproc)"
sudo make install

# Symlink shared libs for UE
cd "$INTERNAL_PYTHON/lib"
sudo ln -sf libpython3.12.so.1.0 libpython3.12.so

#############################################
# 3) ROCm 7.2 Install
# Using 2026 official repositories for "noble"
#############################################
echo "--- Installing ROCm 7.2 ---"
sudo usermod -a -G render,video "$USER"

sudo mkdir --parents --mode=0755 /etc/apt/keyrings
wget https://repo.radeon.com -O - | \
    gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

# Repository for Ubuntu 24.04 (Noble)
sudo tee /etc/apt/sources.list.d/rocm.list << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
EOF

sudo apt update
sudo apt install -y rocm-dkms rocm-dev hipblas miopen-hip

#############################################
# 4) PyTorch Note (Updated for 2026)
#############################################
cat << 'EOF'

========================================
PyTorch ROCm 7.2 Setup (Python 3.12):
========================================
To install the latest PyTorch (v2.10) with ROCm 7.2 support:

    python3.12 -m venv ~/ue_rocm_env
    source ~/ue_rocm_env/bin/activate
    pip install --upgrade pip wheel
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org

Note: Use 'export HSA_OVERRIDE_GFX_VERSION=11.0.0' if using consumer RDNA3 cards.
========================================
EOF
