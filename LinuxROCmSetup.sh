#!/usr/bin/env bash
set -euo pipefail

#############################################
# Linux ROCm 7.2 + UE Python 3.12 + PyTorch
# Updated: January 23, 2026
#############################################

UE_PATH="/media/joematrix/Storage/UE_5.7"
INTERNAL_PYTHON="$UE_PATH/Engine/Binaries/ThirdParty/Python3/Linux"
TEMP_DIR="/tmp/ue_python_setup"

echo "--- Cleaning up previous build attempts ---"
# Use sudo for rm to fix the 'Permission denied' error in /tmp
sudo rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

#############################################
# 1) Install System Dependencies
#############################################
echo "--- Installing system build dependencies ---"
sudo apt update
sudo apt install -y build-essential wget curl xz-utils \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncurses-dev \
    tk-dev liblzma-dev pkg-config git \
    python3.12-dev python3.12-venv python3-pip

#############################################
# 2) Build Internal Python 3.12
#############################################
echo "--- Downloading Python 3.12.8 Source ---"
cd "$TEMP_DIR"
PYTHON_VER="3.12.8"
PYTHON_TAR="Python-$PYTHON_VER.tar.xz"
PYTHON_URL="https://www.python.org/ftp/python/3.12.8/Python-3.12.8.tar.xz"

# Using Curl with browser headers to bypass server blocks
curl -L -A "Mozilla/5.0" "$PYTHON_URL" -o "$PYTHON_TAR"

echo "--- Extracting and Building ---"
tar -xf "$PYTHON_TAR"
cd "Python-$PYTHON_VER"

./configure --prefix="$INTERNAL_PYTHON" --enable-shared --with-system-ffi \
    CFLAGS="-fPIC" LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"
make -j"$(nproc)"
sudo make install

# Fix permissions on the internal Python directory so UE can use it
sudo chown -R $USER:$USER "$INTERNAL_PYTHON"

# Symlink shared libs for UE
cd "$INTERNAL_PYTHON/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so

#############################################
# 3) ROCm 7.2 Installation (GPG Fix)
#############################################
echo "--- Configuring ROCm 7.2 (January 2026) ---"
sudo mkdir -p /etc/apt/keyrings

# Fixed GPG Download: Bypassing server blocks
curl -L -A "Mozilla/5.0" https://repo.radeon.com | \
gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rocm.list << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com noble main
EOF

sudo apt update
sudo apt install -y rocm-dkms rocm-dev hipblas miopen-hip

#############################################
# 4) PyTorch venv Setup (User Level)
#############################################
echo "--- Creating PyTorch ROCm 7.2 Environment ---"
# Do NOT use sudo here
python3.12 -m venv ~/ue_rocm_env
source ~/ue_rocm_env/bin/activate

# Upgrade pip inside the venv
pip install --upgrade pip wheel

# Install PyTorch for ROCm 7.2
pip install torch torchvision torchaudio --index-url https://download.pytorch.org

echo "========================================="
echo "Setup Complete!"
echo "To use: source ~/ue_rocm_env/bin/activate"
echo "========================================="
