#!/usr/bin/env bash
set -euo pipefail

#############################################
# Linux ROCm 7.2 + UE Python 3.12 Setup
# Updated: Jan 22, 2026 
#############################################

UE_PATH="/media/joematrix/Storage/UE_5.7"
INTERNAL_PYTHON="$UE_PATH/Engine/Binaries/ThirdParty/Python3/Linux"
TEMP_DIR="/tmp/ue_python_setup"

echo "--- Installing system build dependencies ---"
sudo apt update
# 2026 Note: libncurses-dev is the correct package for Ubuntu 24.04
sudo apt install -y build-essential wget curl xz-utils \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncurses-dev \
    tk-dev liblzma-dev pkg-config git \
    python3.12-dev python3.12-venv python3-pip

#############################################
# 1) Download and Install Internal Python 3.12
#############################################
echo "--- Downloading Python 3.12.8 Source ---"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR" && cd "$TEMP_DIR"

PYTHON_VER="3.12.8"
PYTHON_TAR="Python-$PYTHON_VER.tar.xz"
# Direct binary URL
PYTHON_URL="https://www.python.org"

# FIX: Use User-Agent AND Referer to bypass server-side blocks
wget --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" \
     --header="Referer: 

https://www.python.org/downloads/source/
" \
     "$PYTHON_URL" -O "$PYTHON_TAR"

# Verification: Source archive should be ~20MB (20,000,000+ bytes)
FILE_SIZE=$(stat -c%s "$PYTHON_TAR")
if [ "$FILE_SIZE" -lt 10000000 ]; then
    echo "ERROR: Download failed. File size is only $FILE_SIZE bytes (expected ~20MB)."
    echo "The server is still blocking the automated request."
    exit 1
fi

echo "--- Extracting and Building Python ---"
tar -xf "$PYTHON_TAR"
cd "Python-$PYTHON_VER"

./configure --prefix="$INTERNAL_PYTHON" --enable-shared --with-system-ffi \
    CFLAGS="-fPIC" LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"
make -j"$(nproc)"
sudo make install

# Symlink shared libs for UE
cd "$INTERNAL_PYTHON/lib"
sudo ln -sf libpython3.12.so.1.0 libpython3.12.so

#############################################
# 2) ROCm 7.2 Installation
#############################################
echo "--- Configuring ROCm 7.2 for Noble ---"
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://repo.radeon.com | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rocm.list << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
EOF

sudo apt update
sudo apt install -y rocm-dkms rocm-dev hipblas miopen-hip

#############################################
# 3) Immediate PyTorch Environment Setup
#############################################
echo "--- Setting up PyTorch in Virtual Environment ---"
python3.12 -m venv ~/ue_rocm_env
source ~/ue_rocm_env/bin/activate
pip install --upgrade pip wheel

# Install PyTorch for ROCm 7.2 (Latest 2026 Release)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org

echo "--- Setup Complete! ---"
echo "To use your environment: source ~/ue_rocm_env/bin/activate"
