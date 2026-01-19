# Unreal Engine 5.7 ROCm Setup Script
# Copyright 2026 Joe Castro / Matrix Networx
#
# This script upgrades UE 5.7's embedded Python to 3.12 and installs
# PyTorch with ROCm support for AMD Radeon GPUs (RX 7000/9000 series)
#
# Usage: .\Setup-ROCm.ps1 -UEPath "S:\UE_5.7"

param(
    [Parameter(Mandatory=$true)]
    [string]$UEPath,

    [switch]$SkipBackup,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Unreal Engine 5.7 ROCm Setup" -ForegroundColor Cyan
Write-Host "PyTorch 2.9 + ROCm 7.1.1 for AMD GPUs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Validate UE path
$PythonDir = Join-Path $UEPath "Engine\Binaries\ThirdParty\Python3\Win64"
if (!(Test-Path $PythonDir)) {
    Write-Host "[ERROR] UE Python directory not found: $PythonDir" -ForegroundColor Red
    Write-Host "Make sure you've built UE 5.7 at least once." -ForegroundColor Yellow
    exit 1
}

# Check current Python version
$CurrentPython = Join-Path $PythonDir "python.exe"
if (Test-Path $CurrentPython) {
    $version = & $CurrentPython --version 2>&1
    Write-Host "[INFO] Current Python: $version" -ForegroundColor Gray

    if ($version -match "3\.12" -and !$Force) {
        Write-Host "[INFO] Python 3.12 already installed. Use -Force to reinstall." -ForegroundColor Yellow
        exit 0
    }
}

# Step 1: Backup existing Python
if (!$SkipBackup) {
    Write-Host "`n[1/6] Backing up existing Python..." -ForegroundColor Yellow
    $BackupDir = Join-Path (Split-Path $PythonDir) "Win64_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $PythonDir -Destination $BackupDir -Recurse -Force
    Write-Host "      Backup created: $BackupDir" -ForegroundColor Green
} else {
    Write-Host "`n[1/6] Skipping backup (--SkipBackup)" -ForegroundColor Gray
}

# Step 2: Download Python 3.12
Write-Host "`n[2/6] Downloading Python 3.12.8..." -ForegroundColor Yellow
$PythonZip = Join-Path $env:TEMP "python-3.12.8-embed-amd64.zip"
$PythonUrl = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-embed-amd64.zip"

try {
    Invoke-WebRequest -Uri $PythonUrl -OutFile $PythonZip -UseBasicParsing
    Write-Host "      Downloaded to: $PythonZip" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to download Python: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Extract Python
Write-Host "`n[3/6] Installing Python 3.12..." -ForegroundColor Yellow
Remove-Item "$PythonDir\*" -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $PythonZip -DestinationPath $PythonDir -Force

# Configure python312._pth for pip/site-packages
$PthFile = Join-Path $PythonDir "python312._pth"
@"
python312.zip
.
Lib\site-packages

# Enable site-packages for pip
import site
"@ | Set-Content -Path $PthFile -Encoding UTF8

# Create site-packages directory
New-Item -ItemType Directory -Path (Join-Path $PythonDir "Lib\site-packages") -Force | Out-Null

Write-Host "      Python 3.12.8 installed" -ForegroundColor Green

# Step 4: Install pip
Write-Host "`n[4/6] Installing pip..." -ForegroundColor Yellow
$GetPip = Join-Path $env:TEMP "get-pip.py"
Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $GetPip -UseBasicParsing
$Python = Join-Path $PythonDir "python.exe"
& $Python $GetPip --no-warn-script-location 2>&1 | Out-Null
Write-Host "      pip installed" -ForegroundColor Green

# Step 5: Install ROCm PyTorch
Write-Host "`n[5/6] Installing PyTorch with ROCm (this may take a while)..." -ForegroundColor Yellow
$RocmRepo = "https://repo.radeon.com/rocm/windows/rocm-rel-7.1.1"

# Install wheels without dependencies first
$wheels = @(
    "$RocmRepo/torch-2.9.0%2Brocmsdk20251116-cp312-cp312-win_amd64.whl",
    "$RocmRepo/torchvision-0.24.0%2Brocmsdk20251116-cp312-cp312-win_amd64.whl",
    "$RocmRepo/rocm_sdk_core-0.1.dev0-py3-none-win_amd64.whl",
    "$RocmRepo/rocm_sdk_libraries_custom-0.1.dev0-py3-none-win_amd64.whl"
)

foreach ($wheel in $wheels) {
    Write-Host "      Installing: $(Split-Path $wheel -Leaf)" -ForegroundColor Gray
    & $Python -m pip install --no-deps --no-cache-dir $wheel 2>&1 | Out-Null
}

# Install rocm meta-package
Write-Host "      Installing: rocm-0.1.dev0" -ForegroundColor Gray
& $Python -m pip install --no-cache-dir "$RocmRepo/rocm-0.1.dev0.tar.gz" 2>&1 | Out-Null

# Install Python dependencies
Write-Host "      Installing dependencies..." -ForegroundColor Gray
& $Python -m pip install filelock typing-extensions sympy networkx jinja2 fsspec numpy pillow setuptools 2>&1 | Out-Null

Write-Host "      PyTorch 2.9.0 + ROCm installed" -ForegroundColor Green

# Step 6: Install ML packages
Write-Host "`n[6/6] Installing ML packages (transformers, ultralytics)..." -ForegroundColor Yellow
& $Python -m pip install transformers ultralytics huggingface-hub 2>&1 | Out-Null
Write-Host "      ML packages installed" -ForegroundColor Green

# Verification
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Verifying installation..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$VerifyScript = @"
import torch
print(f'PyTorch: {torch.__version__}')
print(f'ROCm available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
    print(f'Device count: {torch.cuda.device_count()}')
else:
    print('WARNING: No GPU detected. Make sure AMD ROCm driver is installed.')
"@

$result = & $Python -c $VerifyScript 2>&1
Write-Host $result -ForegroundColor $(if ($result -match "ROCm available: True") { "Green" } else { "Yellow" })

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor White
Write-Host "1. Install AMD Software: PyTorch on Windows Edition 7.1.1 driver" -ForegroundColor Gray
Write-Host "   https://www.amd.com/en/support" -ForegroundColor Gray
Write-Host "2. Rebuild Unreal Engine if needed" -ForegroundColor Gray
Write-Host "3. Test GPU acceleration in your Python scripts" -ForegroundColor Gray
