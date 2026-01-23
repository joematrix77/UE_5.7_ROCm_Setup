#!/usr/bin/env bash
set -euo pipefail

#############################################
# Linux ROCm 7.2 + UE Python 3.12 + PyTorch Setup
# Updated: January 23, 2026
#############################################

UE_PATH="/media/joematrix/Storage/UE_5.7"
INTERNAL_PYTHON="$UE_PATH/Engine/Binaries/ThirdParty/Python3/Linux"
TEMP_DIR="/tmp/ue_python_setup"

echo "--- Installing system build dependencies ---"
sudo apt update
# 2026 Ubuntu 24.04 (Noble) uses libncurses-dev
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
# FIXED: Absolute direct URL to the source tarball
PYTHON_URL="https://www.python.org/ftp/python/3.12.8/Python-3.12.8.tar.xz"

# Using CURL with browser-mimicking headers to avoid blocks
curl -L -A "Mozilla/5.0" "$PYTHON_URL" -o "$PYTHON_TAR"

# Verification: The source tarball is approximately 20MB
FILE_SIZE=$(stat -c%s "$PYTHON_TAR")
if [ "$FILE_SIZE" -lt 15000000 ]; then
    echo "ERROR: Download failed. File size is only $FILE_SIZE bytes (expected ~20MB)."
    echo "Check the URL directly: $PYTHON_URL"
    exit 1
fi

echo "--- Extracting and Building Python ---"
tar -xf "$PYTHON_TAR"
cd "Python-$PYTHON_VER"

./configure --prefix="$INTERNAL_PYTHON" --enable-shared --with-system-ffi \
    CFLAGS="-fPIC" LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"
make -j"$(nproc)"
sudo make install

# Symlink shared libs for UE compatibility
cd "$INTERNAL_PYTHON/lib"
sudo ln -sf libpython3.12.so.1.0 libpython3.12.so

#############################################
# 2) ROCm 7.2 Installation
#############################################
echo "--- Configuring ROCm 7.2 (Latest 2026 Repo) ---"
# Ensure the keyring directory exists
sudo mkdir --parents --mode=0755 /etc/apt/keyrings

# Download the 2026 GPG key using browser-like headers to bypass server blocks
curl -L -A "Mozilla/5.0" https://repo.radeon.com/rocm/rocm.gpg.key | \
gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rocm.list << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
EOF

sudo apt update
sudo apt install -y rocm-dkms rocm-dev hipblas miopen-hip

#############################################
# 3) Immediate PyTorch venv Setup
#############################################
echo "--- Creating PyTorch ROCm 7.2 Environment ---"
python3.12 -m venv ~/ue_rocm_env
source ~/ue_rocm_env/bin/activate
pip install --upgrade pip wheel

# Install PyTorch for ROCm 7.2 (Stable release as of Jan 2026)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org

echo "========================================="
echo "Setup Complete!"
echo "To use: source ~/ue_rocm_env/bin/activate"
echo "========================================="
