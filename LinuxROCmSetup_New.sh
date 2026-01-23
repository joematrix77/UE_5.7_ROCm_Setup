#!/usr/bin/env bash
set -e

#############################################
# CONFIG — EDIT IF YOUR UE PATH DIFFERS
#############################################

UE_ROOT="/media/joematrix/Storage/UE_5.7"
UE_PYTHON="${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux/bin/python3"
UE_SITE_PACKAGES="${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux/venv_torch/lib/python3.12/site-packages"

#############################################
# PRE-FLIGHT
#############################################

echo "=== UE ROCm + PyTorch Setup (Linux / Source Build) ==="

if [[ ! -x "$UE_PYTHON" ]]; then
    echo "ERROR: UE embedded Python not found:"
    echo "  $UE_PYTHON"
    exit 1
fi

#############################################
# USER GROUPS
#############################################

echo "--- Adding user to render/video groups ---"
sudo usermod -a -G render,video "$USER"

#############################################
# ROCm 7.2 REPOSITORY (UBUNTU 24.04 NOBLE)
#############################################

echo "--- Installing ROCm 7.2 repo (Noble) ---"

sudo mkdir -p /etc/apt/keyrings

wget -q https://repo.radeon.com/rocm/rocm.gpg.key -O - | \
    gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rocm.list << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.2 noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/7.2/ubuntu noble main
EOF

sudo tee /etc/apt/preferences.d/rocm-pin-600 << EOF
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600
EOF

sudo apt update

#############################################
# ROCm INSTALL
#############################################

echo "--- Installing ROCm packages ---"
sudo apt install -y \
    rocm-dev \
    rocm-utils \
    rocminfo \
    rocm-smi \
    hipblas \
    miopen-hip

#############################################
# ENV VARS (UE-FRIENDLY)
#############################################

echo "--- Writing ROCm environment vars ---"
sudo tee /etc/profile.d/rocm.sh << 'EOF'
export ROCM_PATH=/opt/rocm
export HIP_PATH=/opt/rocm
export PATH=$PATH:/opt/rocm/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/lib64
EOF

#############################################
# UE PYTHON — PIP BOOTSTRAP
#############################################

echo "--- Bootstrapping pip in UE Python ---"
"$UE_PYTHON" -m ensurepip --upgrade
"$UE_PYTHON" -m pip install --upgrade pip setuptools wheel

#############################################
# PYTORCH ROCm 7.2 (UE PYTHON ONLY)
#############################################

echo "--- Installing PyTorch (ROCm 7.2) into UE Python ---"

"$UE_PYTHON" -m pip install \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/rocm7.2

#############################################
# EXTRA ML PACKAGES (SAFE SET)
#############################################

echo "--- Installing ML utilities ---"
"$UE_PYTHON" -m pip install \
    numpy \
    scipy \
    pillow \
    tqdm \
    psutil \
    pyyaml

#############################################
# SITE-PACKAGES INJECTION (UE SAFE)
#############################################

echo "--- Adding site-packages hook ---"

cat << EOF
Add this to your UE Python bootstrap if needed:

import site
site.addsitedir(
    "${UE_SITE_PACKAGES}"
)
EOF

#############################################
# SANITY CHECKS
#############################################

echo "--- Verifying PyTorch ROCm ---"

"$UE_PYTHON" - << 'EOF'
import torch
print("Torch version:", torch.__version__)
print("ROCm available:", torch.version.hip is not None)
print("HIP version:", torch.version.hip)
print("GPU count:", torch.cuda.device_count())
EOF

echo "--- Grep check (torch inside UE Python tree) ---"
grep -R "torch/__init__.py" "${UE_SITE_PACKAGES}" || true

#############################################
# DONE
#############################################

echo "============================================"
echo "ROCm 7.2 + PyTorch installed into UE Python"
echo "REBOOT REQUIRED before first use"
echo "============================================"
