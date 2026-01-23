#!/usr/bin/env bash
set -euo pipefail

#############################################
# Linux ROCm 7.2 + UE Python 3.12 Setup
# Updated: Jan 22, 2026
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
# Fixed: libncurses-dev for Ubuntu 24.04 compatibility
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
# Direct URL to the actual archive file
PYTHON_URL="https://www.python.org"

# Using -c to continue and -O to ensure it doesn't save as index.html
wget -c "$PYTHON_URL" -O "Python-$PYTHON_VER.tar.xz"

# Verify file integrity/size (HTML is usually < 50KB, Source is ~20MB)
FILE_SIZE=$(stat -c%s "Python-$PYTHON_VER.tar.xz")
if [ "$FILE_SIZE" -lt 1000000 ]; then
    echo "ERROR: Downloaded file is too small ($FILE_SIZE bytes). It is likely an HTML error page."
    echo "Verify your network or the URL: $PYTHON_URL"
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
# 3) ROCm 7.2 Install (Noble Native)
#############################################
echo "--- Configuring ROCm 7.2 ---"
sudo usermod -a -G render,video "$USER"

sudo mkdir -p /etc/apt/keyrings
wget -qO- https://repo.radeon.com | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

# Official 2026 ROCm 7.2 repo for Ubuntu 24.04 (noble)
sudo tee /etc/apt/sources.list.d/rocm.list << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
EOF

sudo apt update
sudo apt install -y rocm-dkms rocm-dev hipblas miopen-hip

#############################################
# 4) PyTorch 2026 Environment Note
#############################################
cat << 'EOF'

#############################################
PyTorch ROCm 7.2 + Python 3.12 Setup:
#############################################
To complete your setup, create a venv:
    
    python3.12 -m venv ~/ue_rocm_env
    source ~/ue_rocm_env/bin/activate
    pip install torch torchvision --index-url https://download.pytorch.org/whl/rocm7.2

If using an RDNA3 card, run:
    export HSA_OVERRIDE_GFX_VERSION=11.0.0
========================================
EOF
