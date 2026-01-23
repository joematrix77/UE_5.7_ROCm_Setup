#!/usr/bin/env bash
set -euo pipefail

#############################################
# USER CONFIG
#############################################
UE_ROOT="/media/joematrix/Storage/UE_5.7"
PYTHON_VERSION="3.12.8"
ROCM_VERSION="7.1"
PYTHON_ROOT="$UE_ROOT/Engine/Binaries/ThirdParty/Python3/Linux"
VENV_PATH="$PYTHON_ROOT/venv_torch"
TMP_BUILD="/tmp/ue_python_build"

#############################################
# SANITY CHECKS
#############################################
if [[ ! -d "$UE_ROOT/Engine" ]]; then
    echo "ERROR: UE_ROOT is invalid: $UE_ROOT"
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Do NOT run this script as root"
    exit 1
fi

echo "UE ROOT: $UE_ROOT"
echo "Python install path: $PYTHON_ROOT"
echo "ROCm version: $ROCM_VERSION"

#############################################
# 0. SYSTEM DEPENDENCIES
#############################################
echo "=== Installing system dependencies ==="
sudo apt update
sudo apt install -y \
    build-essential cmake ninja-build git curl wget \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncursesw5-dev \
    liblzma-dev tk-dev xz-utils pkg-config \
    libnuma-dev gnupg2 ca-certificates

#############################################
# 1. INSTALL ROCm 7.1
#############################################
echo "=== Installing ROCm 7.1 ==="

sudo usermod -a -G render,video $USER

wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -

echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/${ROCM_VERSION}/ ubuntu main" | \
    sudo tee /etc/apt/sources.list.d/rocm.list

sudo apt update
sudo apt install -y \
    rocm-dkms \
    rocm-dev \
    rocm-utils \
    hipblas \
    miopen-hip

# Environment (once)
if ! grep -q "/opt/rocm" ~/.bashrc; then
cat >> ~/.bashrc <<EOF

# ROCm 7.1
export PATH=/opt/rocm/bin:\$PATH
export LD_LIBRARY_PATH=/opt/rocm/lib:\$LD_LIBRARY_PATH
EOF
fi

#############################################
# 2. BUILD PYTHON FOR UE
#############################################
echo "=== Building Python $PYTHON_VERSION for Unreal Engine ==="

rm -rf "$TMP_BUILD"
mkdir -p "$TMP_BUILD"
cd "$TMP_BUILD"

wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz
tar -xf Python-${PYTHON_VERSION}.tar.xz
cd Python-${PYTHON_VERSION}

./configure \
    --prefix="$PYTHON_ROOT" \
    --enable-shared \
    --with-system-ffi \
    CFLAGS="-fPIC" \
    LDFLAGS="-Wl,-rpath,'\$\$ORIGIN/../lib'"

make -j$(nproc)
make install

cd "$PYTHON_ROOT/lib"
ln -sf libpython3.12.so.1.0 libpython3.12.so
ln -sf libpython3.12.so.1.0 libpython3.12.a

#############################################
# 3. CREATE UE PYTHON VENV
#############################################
echo "=== Creating UE Python venv ==="

"$PYTHON_ROOT/bin/python3" -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

pip install --upgrade pip setuptools wheel

#############################################
# 4. INSTALL PYTORCH (ROCm)
#############################################
echo "=== Installing PyTorch (ROCm 7.1) ==="

pip install --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/rocm/

#############################################
# 5. VERIFY TORCH + ROCm
#############################################
echo "=== Verifying PyTorch ROCm ==="

python <<'EOF'
import torch
print("Torch version:", torch.__version__)
print("HIP version:", torch.version.hip)
print("ROCm available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))
EOF

deactivate

#############################################
# 6. PATCH UE PYTHON BUILD CONFIG
#############################################
echo "=== Patching Unreal Python Build.cs ==="

BUILD_CS="$UE_ROOT/Engine/Source/ThirdParty/Python3/Python3.Build.cs"

if [[ -f "$BUILD_CS" ]]; then
    sed -i 's/libpython3\.12\.a/libpython3.12.so/g' "$BUILD_CS"
    grep -q 'python3.12' "$BUILD_CS" || \
        sed -i '/PublicSystemLibraryPaths.Add/a\        PublicAdditionalLibraries.Add("python3.12");' "$BUILD_CS"
else
    echo "WARNING: Python3.Build.cs not found (skipping)"
fi

import site
site.addsitedir(
    "/media/joematrix/Storage/UE_5.7/Engine/Binaries/ThirdParty/Python3/Linux/venv_torch/lib/python3.12/site-packages"
)

#############################################
# 7. FINAL STEPS
#############################################
echo ""
echo "========================================"
echo " SETUP COMPLETE (ROCm 7.1)"
echo "========================================"
echo ""
echo "NEXT:"
echo "1) Reboot (ROCm drivers + groups)"
echo "2) Clean UE Linux intermediates:"
echo "   rm -rf $UE_ROOT/Engine/Intermediate/Build/Linux"
echo "3) Rebuild UE:"
echo "   cd $UE_ROOT && ./GenerateProjectFiles.sh && make"
echo ""
echo "PyTorch venv:"
echo "  $VENV_PATH"
echo ""
