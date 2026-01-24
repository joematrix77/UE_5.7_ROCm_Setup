#!/usr/bin/env bash
set -e

#############################################
# UE 5.7 Linux ROCm + Python 3.12 Setup
#
# Upgrades UE's embedded Python from 3.11 to 3.12
# and installs ROCm + PyTorch for AMD GPU acceleration
#
# See LINUX_SETUP_CHANGES.md for details on what this modifies
#############################################

#############################################
# CONFIG — EDIT THIS TO MATCH YOUR UE PATH
#############################################

UE_ROOT="${UE_ROOT:-/media/joematrix/Storage/UE_5.7}"
PYTHON_VERSION="3.12.8"
PYTHON_SHORT="3.12"

#############################################
# DERIVED PATHS (DO NOT EDIT)
#############################################

UE_PYTHON_BIN_DIR="${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux"
UE_PYTHON_SRC_DIR="${UE_ROOT}/Engine/Source/ThirdParty/Python3/Linux"
UE_PYTHON="${UE_PYTHON_BIN_DIR}/bin/python3"

#############################################
# COLORS
#############################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $1"; }

#############################################
# USAGE
#############################################

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --ue-path PATH    Path to UE 5.7 source (default: $UE_ROOT)"
    echo "  -s, --skip-python     Skip Python installation (ROCm only)"
    echo "  -r, --skip-rocm       Skip ROCm installation (Python only)"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Environment:"
    echo "  UE_ROOT               Can also be set via environment variable"
    exit 0
}

SKIP_PYTHON=false
SKIP_ROCM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--ue-path) UE_ROOT="$2"; shift 2 ;;
        -s|--skip-python) SKIP_PYTHON=true; shift ;;
        -r|--skip-rocm) SKIP_ROCM=true; shift ;;
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done

#############################################
# PRE-FLIGHT CHECKS
#############################################

echo ""
echo "=========================================="
echo " UE 5.7 Linux ROCm + Python 3.12 Setup"
echo "=========================================="
echo ""

if [[ ! -d "$UE_ROOT" ]]; then
    log_error "UE root not found: $UE_ROOT"
    log_error "Set with: $0 --ue-path /path/to/UE_5.7"
    exit 1
fi

if [[ ! -d "${UE_ROOT}/Engine" ]]; then
    log_error "Engine directory not found. Is this a valid UE source build?"
    exit 1
fi

log_info "UE Path: $UE_ROOT"

#############################################
# STEP 1: INSTALL BUILD DEPENDENCIES
#############################################

log_step "1/10 Installing build dependencies..."

sudo apt update
sudo apt install -y \
    build-essential wget curl \
    libssl-dev libffi-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncurses-dev \
    tk-dev liblzma-dev pkg-config

#############################################
# STEP 2: BACKUP EXISTING PYTHON
#############################################

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

if [[ "$SKIP_PYTHON" == false ]] && [[ -d "${UE_PYTHON_BIN_DIR}/bin" ]]; then
    log_step "2/10 Backing up existing Python..."

    BACKUP_DIR="${UE_PYTHON_BIN_DIR}_backup_${BACKUP_DATE}"
    cp -r "${UE_PYTHON_BIN_DIR}" "$BACKUP_DIR"
    log_info "Backup: $BACKUP_DIR"
else
    log_step "2/10 Skipping backup (no existing installation or --skip-python)"
fi

#############################################
# STEP 3: BUILD AND INSTALL PYTHON 3.12
#############################################

if [[ "$SKIP_PYTHON" == false ]]; then
    log_step "3/10 Building Python ${PYTHON_VERSION} (this takes several minutes)..."

    PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
    TEMP_DIR=$(mktemp -d)

    cd "$TEMP_DIR"
    wget -q --show-progress "$PYTHON_URL" -O "Python-${PYTHON_VERSION}.tgz"
    tar -xzf "Python-${PYTHON_VERSION}.tgz"
    cd "Python-${PYTHON_VERSION}"

    ./configure \
        --prefix="${UE_PYTHON_BIN_DIR}" \
        --enable-shared \
        --enable-optimizations \
        --with-lto \
        LDFLAGS="-Wl,-rpath,${UE_PYTHON_BIN_DIR}/lib" \
        > /dev/null

    make -j$(nproc)
    make install

    cd /
    rm -rf "$TEMP_DIR"

    log_info "Python ${PYTHON_VERSION} installed to ${UE_PYTHON_BIN_DIR}"
else
    log_step "3/10 Skipping Python build (--skip-python)"
fi

#############################################
# STEP 4: SETUP PYTHON HEADERS FOR UE BUILD
#############################################

if [[ "$SKIP_PYTHON" == false ]]; then
    log_step "4/10 Setting up Python headers for UE build..."

    mkdir -p "${UE_PYTHON_SRC_DIR}/include"
    mkdir -p "${UE_PYTHON_SRC_DIR}/lib"

    # Copy headers
    if [[ -d "${UE_PYTHON_BIN_DIR}/include/python${PYTHON_SHORT}" ]]; then
        rm -rf "${UE_PYTHON_SRC_DIR}/include"/*
        cp -r "${UE_PYTHON_BIN_DIR}/include/python${PYTHON_SHORT}"/* "${UE_PYTHON_SRC_DIR}/include/"
        log_info "Headers copied to ${UE_PYTHON_SRC_DIR}/include/"
    else
        log_error "Python headers not found!"
        exit 1
    fi

    # Copy library (as actual file, not symlink - required for UE linker)
    if [[ -f "${UE_PYTHON_BIN_DIR}/lib/libpython${PYTHON_SHORT}.so.1.0" ]]; then
        cp "${UE_PYTHON_BIN_DIR}/lib/libpython${PYTHON_SHORT}.so.1.0" \
           "${UE_PYTHON_SRC_DIR}/lib/libpython${PYTHON_SHORT}.so"
        log_info "Library copied to ${UE_PYTHON_SRC_DIR}/lib/"
    else
        log_error "Python library not found!"
        exit 1
    fi
else
    log_step "4/10 Skipping header setup (--skip-python)"
fi

#############################################
# STEP 5: PATCH UnrealUSDWrapper.Build.cs
#############################################

USD_BUILD_CS="${UE_ROOT}/Engine/Plugins/Runtime/USDCore/Source/UnrealUSDWrapper/UnrealUSDWrapper.Build.cs"

if [[ "$SKIP_PYTHON" == false ]] && [[ -f "$USD_BUILD_CS" ]]; then
    log_step "5/10 Patching UnrealUSDWrapper.Build.cs..."

    # Backup
    cp "$USD_BUILD_CS" "${USD_BUILD_CS}.backup_${BACKUP_DATE}"

    if grep -q "libpython${PYTHON_SHORT}.so" "$USD_BUILD_CS"; then
        log_info "Already patched for Python ${PYTHON_SHORT}"
    else
        # Replace python3.11 references
        sed -i "s/python3\.11/python${PYTHON_SHORT}/g" "$USD_BUILD_CS"

        # Add explicit library linking after the library path line
        sed -i '/PublicSystemLibraryPaths.Add(Path.Combine(PythonBinaryTPSDir, "lib"));/a\
					// Link against Python '"${PYTHON_SHORT}"' library (added by LinuxROCmSetup.sh)\
					PublicAdditionalLibraries.Add(Path.Combine(PythonSourceTPSDir, "lib", "libpython'"${PYTHON_SHORT}"'.so"));' "$USD_BUILD_CS"

        # Update RuntimeDependencies
        sed -i 's|RuntimeDependencies.Add(Path.Combine(PythonBinaryTPSDir, "bin", "python3.11"))|RuntimeDependencies.Add(Path.Combine(PythonBinaryTPSDir, "lib", "libpython'"${PYTHON_SHORT}"'.so.1.0"))|g' "$USD_BUILD_CS"

        log_info "Patched successfully"
    fi
else
    log_step "5/10 Skipping Build.cs patch"
fi

#############################################
# STEP 6: USER GROUPS FOR ROCm
#############################################

if [[ "$SKIP_ROCM" == false ]]; then
    log_step "6/10 Adding user to render/video groups..."
    sudo usermod -a -G render,video "$USER"
else
    log_step "6/10 Skipping user groups (--skip-rocm)"
fi

#############################################
# STEP 7: ROCm REPOSITORY
#############################################

if [[ "$SKIP_ROCM" == false ]]; then
    log_step "7/10 Setting up ROCm 7.2 repository..."

    sudo mkdir -p /etc/apt/keyrings

    wget -q https://repo.radeon.com/rocm/rocm.gpg.key -O - | \
        gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null

    UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "noble")

    sudo tee /etc/apt/sources.list.d/rocm.list > /dev/null << EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.2 ${UBUNTU_CODENAME} main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/7.2/ubuntu ${UBUNTU_CODENAME} main
EOF

    sudo tee /etc/apt/preferences.d/rocm-pin-600 > /dev/null << EOF
Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600
EOF

    sudo apt update
else
    log_step "7/10 Skipping ROCm repository (--skip-rocm)"
fi

#############################################
# STEP 8: ROCm INSTALL
#############################################

if [[ "$SKIP_ROCM" == false ]]; then
    log_step "8/10 Installing ROCm packages..."
    sudo apt install -y \
        rocm-dev rocm-utils rocminfo rocm-smi \
        hipblas miopen-hip

    # Environment variables
    sudo tee /etc/profile.d/rocm.sh > /dev/null << 'EOF'
export ROCM_PATH=/opt/rocm
export HIP_PATH=/opt/rocm
export PATH=$PATH:/opt/rocm/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/lib64
EOF

    source /etc/profile.d/rocm.sh 2>/dev/null || true
else
    log_step "8/10 Skipping ROCm install (--skip-rocm)"
fi

#############################################
# STEP 9: PIP + PYTORCH
#############################################

if [[ "$SKIP_PYTHON" == false ]]; then
    log_step "9/10 Installing pip and PyTorch..."

    "$UE_PYTHON" -m ensurepip --upgrade
    "$UE_PYTHON" -m pip install --upgrade pip setuptools wheel

    if [[ "$SKIP_ROCM" == false ]]; then
        "$UE_PYTHON" -m pip install \
            torch torchvision torchaudio \
            --index-url https://download.pytorch.org/whl/rocm7.2
    fi

    "$UE_PYTHON" -m pip install \
        numpy scipy pillow tqdm psutil pyyaml \
        transformers huggingface-hub
else
    log_step "9/10 Skipping pip/PyTorch (--skip-python)"
fi

#############################################
# STEP 10: VERIFICATION
#############################################

log_step "10/10 Verifying installation..."

echo ""
echo "--- Python ---"
"$UE_PYTHON" --version 2>/dev/null || echo "Python not found"

echo ""
echo "--- UE Build Files ---"
HEADER_COUNT=$(ls "${UE_PYTHON_SRC_DIR}/include"/*.h 2>/dev/null | wc -l)
echo "Headers: ${HEADER_COUNT} files in ${UE_PYTHON_SRC_DIR}/include/"

if [[ -f "${UE_PYTHON_SRC_DIR}/lib/libpython${PYTHON_SHORT}.so" ]]; then
    echo "Library: OK (${UE_PYTHON_SRC_DIR}/lib/libpython${PYTHON_SHORT}.so)"
else
    echo "Library: NOT FOUND"
fi

if [[ "$SKIP_ROCM" == false ]]; then
    echo ""
    echo "--- PyTorch ROCm ---"
    "$UE_PYTHON" -c "
import torch
print(f'Torch: {torch.__version__}')
print(f'ROCm: {torch.version.hip}')
print(f'GPUs: {torch.cuda.device_count()}')
" 2>/dev/null || echo "PyTorch check failed"
fi

#############################################
# DONE
#############################################

echo ""
echo "=========================================="
echo " Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. REBOOT (required for ROCm group membership)"
echo ""
echo "2. Regenerate UE project files:"
echo "   cd ${UE_ROOT}"
echo "   ./GenerateProjectFiles.sh"
echo ""
echo "3. Build UE Editor:"
echo "   make UnrealEditor-Linux-Development -j\$(nproc)"
echo ""
echo "=========================================="
