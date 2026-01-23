#!/usr/bin/env bash
set -euo pipefail

#############################################
# === USER CONFIGURATION ===
#############################################
UE_PATH="/media/joematrix/Storage/UE_5.7"
PYTHON_VER="3.12.8"
ROCM_VERSION="7.1"
TEMP_DIR="/tmp/python312_rocm_setup"
INTERNAL_PYTHON="$UE_PATH/Engine/Binaries/ThirdParty/Python3/Linux"
VENV_PATH="$INTERNAL_PYTHON/venv_torch"

#############################################
# === SANITY CHECKS ===
#############################################
if [[ ! -d "$UE_PATH/Engine" ]]; then
    echo "ERROR: UE_PATH invalid: $UE_PATH"
    exit 1
fi
if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Do not run this script as root"
    exit 1
fi

echo "========================================"
echo "Installing Python3.12 + ROCm 7.1 + PyTorch"
echo "UE Path   : $UE_PATH"
echo "Python Ver: $PYTHON_VER"
echo "ROCm Ver  : $ROCM_VERSION"
echo "========================================"

#############################################
# === APT SYSTEM DEPENDENCIES ===
#############################################
echo "--- Installing base dependencies ---"
sudo apt update
sudo apt install -y \
    wget curl tar xz-utils build-essential cmake ninja-build git \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncursesw5-dev \
    liblzma-dev tk-dev pkg-config libnuma-dev gnupg2 ca-certificates

#############################################
# === ROCm 7.1 INSTALL ===
#############################################
echo "--- Installing ROCm 7.1 ---"
sudo usermod -a -G render,video "$USER"

# modern keyring instead of apt-key
wget -q https://repo.radeon.com/rocm/rocm.gpg.key -O /tmp/rocm.gpg
sudo gpg --dearmor -o /usr/share/keyrings/rocm.gpg /tmp/rocm.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.1/ jammy main" | \
    sudo tee /etc/apt/sources.list.d/rocm.list

sudo apt update
sudo apt install -y rocm-dkms rocm-dev rocm-utils hipblas miopen-hip

# add ROCm to user profile
if ! grep -q "/opt/rocm" ~/.bashrc; then
cat >> ~/.bashrc <<EOF

# ROCm 7.1 environment
export PATH=/opt/rocm/bin:\$PATH
export LD_LIBRARY_PATH=/opt/rocm/lib:\$LD_LIBRARY_PATH
EOF
fi

#############################################
# === BUILD INTERNAL PYTHON 3.12 ===
#############################################
echo "--- Building Python $PYTHON_VER for UE ---"

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR" && cd "$TEMP_DIR"

wget "https://www.python.org/ftp/python/$PYTHON_VER/Python-$PYTHON_VER.tar.xz"
tar -xf "Python-$PYTHON_VER.tar.xz"
cd "Python-$PYTHON_VER"

./configure \
    --prefix="$INTERNAL_PYTHON" \
    --enable-shared \
    --with-system-ffi \
    CFLAGS="-fPIC" \
    LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"

make -j"$(nproc)"
make install

# symlink shared libs for UE build
cd "$INTERNAL_PYTHON/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

#############################################
# === CREATE UE PYTHON VENV & INSTALL TORCH ===
#############################################
echo "--- Creating Python venv and installing PyTorch (ROCm 7.1) ---"

"$INTERNAL_PYTHON/bin/python3" -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

pip install --upgrade pip setuptools wheel

pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/rocm7.1

#############################################
# === VERIFY ROCM + PYTORCH ===
#############################################
echo "--- Verifying ROCm + PyTorch ---"

python << 'EOF'
import torch
print("Torch version:", torch.__version__)
print("HIP version  :", torch.version.hip)
print("ROCm available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("Primary GPU:", torch.cuda.get_device_name(0))
EOF

deactivate

#############################################
# === PATCH UE PYTHON BUILD CONFIG ===
#############################################
echo "--- Patching Unreal Python Build config ---"
BUILD_CS="$UE_PATH/Engine/Source/ThirdParty/Python3/Python3.Build.cs"
if [[ -f "$BUILD_CS" ]]; then
    sed -i 's/libpython3\.12\.a/libpython3.12.so/g' "$BUILD_CS"
    grep -q "python3.12" "$BUILD_CS" || \
        sed -i '/PublicSystemLibraryPaths.Add/a\        PublicAdditionalLibraries.Add("python3.12");' "$BUILD_CS"
else
    echo "WARNING: Python build config not found at $BUILD_CS"
fi

#############################################
# === ROCM GPU LOW-LEVEL CHECK ===
#############################################
echo "--- ROCm low-level GPU check ---"
/opt/rocm/bin/rocminfo | grep gfx || \
    echo "WARNING: ROCm did not report gfx targets. Ensure your GPU is supported!"

#############################################
# === FINAL INSTRUCTIONS + SNIPPET ===
#############################################
echo ""
echo "========================================"
echo "INSTALLATION COMPLETE"
echo "========================================"
echo ""
echo "NEXT STEPS:"
echo "1) Reboot (ensures ROCm drivers + groups take effect)."
echo "2) Clean UE Linux Intermediate:"
echo "   rm -rf $UE_PATH/Engine/Intermediate/Build/Linux"
echo "3) Rebuild UE:"
echo "   cd $UE_PATH && ./GenerateProjectFiles.sh && make"
echo ""
echo "To make Unreal Python use PyTorch, add this at runtime:"
cat << 'EOF'
import site
site.addsitedir(
    "'$VENV_PATH'/lib/python3.12/site-packages"
)
EOF
echo ""
