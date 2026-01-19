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

$TotalSteps = 9
$CurrentStep = 0

# Step 1: Backup existing Python runtime
$CurrentStep++
if (!$SkipBackup) {
    Write-Host "`n[$CurrentStep/$TotalSteps] Backing up existing Python runtime..." -ForegroundColor Yellow
    $BackupDir = Join-Path (Split-Path $PythonDir) "Win64_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $PythonDir -Destination $BackupDir -Recurse -Force
    Write-Host "      Backup created: $BackupDir" -ForegroundColor Green
} else {
    Write-Host "`n[$CurrentStep/$TotalSteps] Skipping backup (--SkipBackup)" -ForegroundColor Gray
}

# Step 2: Download Python 3.12 embeddable
$CurrentStep++
Write-Host "`n[$CurrentStep/$TotalSteps] Downloading Python 3.12.8 embeddable..." -ForegroundColor Yellow
$PythonZip = Join-Path $env:TEMP "python-3.12.8-embed-amd64.zip"
$PythonUrl = "https://www.python.org/ftp/python/3.12.8/python-3.12.8-embed-amd64.zip"

try {
    Invoke-WebRequest -Uri $PythonUrl -OutFile $PythonZip -UseBasicParsing
    Write-Host "      Downloaded to: $PythonZip" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to download Python: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Extract Python runtime
$CurrentStep++
Write-Host "`n[$CurrentStep/$TotalSteps] Installing Python 3.12 runtime..." -ForegroundColor Yellow
Remove-Item "$PythonDir\*" -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $PythonZip -DestinationPath $PythonDir -Force

# Extract stdlib from python312.zip to Lib folder (UE expects this)
Write-Host "      Extracting standard library for UE compatibility..." -ForegroundColor Gray
$StdlibZip = Join-Path $PythonDir "python312.zip"
$LibDir = Join-Path $PythonDir "Lib"
New-Item -ItemType Directory -Path $LibDir -Force | Out-Null
Expand-Archive -Path $StdlibZip -DestinationPath $LibDir -Force

# Configure python312._pth for pip/site-packages
$PthFile = Join-Path $PythonDir "python312._pth"
@"
python312.zip
.
Lib
Lib\site-packages

# Enable site-packages for pip
import site
"@ | Set-Content -Path $PthFile -Encoding UTF8

# Create site-packages directory
New-Item -ItemType Directory -Path (Join-Path $PythonDir "Lib\site-packages") -Force | Out-Null

Write-Host "      Python 3.12.8 runtime installed" -ForegroundColor Green

# Step 4: Download and install Python 3.12 development files (CRITICAL for C++ builds)
$CurrentStep++
Write-Host "`n[$CurrentStep/$TotalSteps] Installing Python 3.12 development files (headers + libs)..." -ForegroundColor Yellow
Write-Host "      This is CRITICAL for UE C++ compilation!" -ForegroundColor Magenta

$NugetUrl = "https://www.nuget.org/api/v2/package/python/3.12.8"
$NugetPkg = Join-Path $env:TEMP "python312-nuget.nupkg"
$NugetExtract = Join-Path $env:TEMP "python312-nuget"

# Download NuGet package
Write-Host "      Downloading Python 3.12 NuGet package..." -ForegroundColor Gray
Invoke-WebRequest -Uri $NugetUrl -OutFile $NugetPkg -UseBasicParsing

# Extract NuGet package
if (Test-Path $NugetExtract) { Remove-Item $NugetExtract -Recurse -Force }
Expand-Archive -Path $NugetPkg -DestinationPath $NugetExtract -Force

$SourceInclude = Join-Path $NugetExtract "tools\include"
$SourceLibs = Join-Path $NugetExtract "tools\libs"

if (!(Test-Path $SourceInclude)) {
    Write-Host "[ERROR] Include directory not found in NuGet package" -ForegroundColor Red
    exit 1
}

# Install headers to Win64
$TargetIncludeWin64 = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\Win64\include"
$BackupSuffix = Get-Date -Format "yyyyMMdd_HHmmss"

if (Test-Path $TargetIncludeWin64) {
    $BackupInclude = "${TargetIncludeWin64}_backup_${BackupSuffix}"
    Write-Host "      Backing up existing headers: $BackupInclude" -ForegroundColor Gray
    Rename-Item $TargetIncludeWin64 $BackupInclude
}
Copy-Item -Path $SourceInclude -Destination $TargetIncludeWin64 -Recurse -Force
Write-Host "      Installed Python 3.12 headers to Win64" -ForegroundColor Green

# Install headers to WinArm64 if exists
$TargetIncludeArm64 = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\WinArm64\include"
if (Test-Path (Split-Path $TargetIncludeArm64)) {
    if (Test-Path $TargetIncludeArm64) {
        Rename-Item $TargetIncludeArm64 "${TargetIncludeArm64}_backup_${BackupSuffix}"
    }
    Copy-Item -Path $SourceInclude -Destination $TargetIncludeArm64 -Recurse -Force
    Write-Host "      Installed Python 3.12 headers to WinArm64" -ForegroundColor Green
}

# Install python312.lib
$TargetLibsWin64 = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\Win64\libs"
if (Test-Path $SourceLibs) {
    if (!(Test-Path $TargetLibsWin64)) {
        New-Item -ItemType Directory -Path $TargetLibsWin64 -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $SourceLibs "python312.lib") -Destination $TargetLibsWin64 -Force
    Copy-Item -Path (Join-Path $SourceLibs "python3.lib") -Destination $TargetLibsWin64 -Force
    Write-Host "      Installed python312.lib to libs directory" -ForegroundColor Green
}

# Verify the fix - check pyconfig.h references python312
$PyConfigPath = Join-Path $TargetIncludeWin64 "pyconfig.h"
if (Test-Path $PyConfigPath) {
    $pyconfig = Get-Content $PyConfigPath -Raw
    if ($pyconfig -match 'pragma comment.*python312\.lib') {
        Write-Host "      VERIFIED: pyconfig.h references python312.lib" -ForegroundColor Green
    } elseif ($pyconfig -match 'pragma comment.*python311\.lib') {
        Write-Host "      [ERROR] pyconfig.h still references python311.lib!" -ForegroundColor Red
        exit 1
    }
}

# Step 5: Patch Engine Build.cs files
$CurrentStep++
Write-Host "`n[$CurrentStep/$TotalSteps] Patching Engine Build.cs files for Python 3.12..." -ForegroundColor Yellow

# Patch Python3.Build.cs
$Python3BuildCs = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\Python3.Build.cs"
if (Test-Path $Python3BuildCs) {
    $content = Get-Content $Python3BuildCs -Raw
    if ($content -match "python311") {
        $newContent = $content -replace 'python311', 'python312' -replace 'python3\.11', 'python3.12' -replace 'Python311', 'Python312'
        Set-Content -Path $Python3BuildCs -Value $newContent -NoNewline
        Write-Host "      Patched Python3.Build.cs" -ForegroundColor Green
    } elseif ($content -match "python312") {
        Write-Host "      Python3.Build.cs already patched" -ForegroundColor Gray
    }
} else {
    Write-Host "      [WARN] Python3.Build.cs not found" -ForegroundColor Yellow
}

# Patch Boost.Build.cs
$BoostBuildCs = Join-Path $UEPath "Engine\Source\ThirdParty\Boost\Boost.Build.cs"
if (Test-Path $BoostBuildCs) {
    $content = Get-Content $BoostBuildCs -Raw
    if ($content -match '"python311"') {
        $newContent = $content -replace '"python311"', '"python312"'
        Set-Content -Path $BoostBuildCs -Value $newContent -NoNewline
        Write-Host "      Patched Boost.Build.cs" -ForegroundColor Green
    } elseif ($content -match '"python312"') {
        Write-Host "      Boost.Build.cs already patched" -ForegroundColor Gray
    }
} else {
    Write-Host "      [WARN] Boost.Build.cs not found" -ForegroundColor Yellow
}

# Patch UnrealUSDWrapper.Build.cs
$USDWrapperBuildCs = Join-Path $UEPath "Engine\Plugins\Runtime\USDCore\Source\UnrealUSDWrapper\UnrealUSDWrapper.Build.cs"
if (Test-Path $USDWrapperBuildCs) {
    $content = Get-Content $USDWrapperBuildCs -Raw
    if ($content -match "python311\.dll") {
        $newContent = $content -replace 'python311\.dll', 'python312.dll'
        Set-Content -Path $USDWrapperBuildCs -Value $newContent -NoNewline
        Write-Host "      Patched UnrealUSDWrapper.Build.cs" -ForegroundColor Green
    } elseif ($content -match "python312\.dll") {
        Write-Host "      UnrealUSDWrapper.Build.cs already patched" -ForegroundColor Gray
    }
} else {
    Write-Host "      [INFO] UnrealUSDWrapper.Build.cs not found (USD plugin may not be installed)" -ForegroundColor Gray
}

# Step 6: Verify/Install Boost.Python 3.12 libraries
$CurrentStep++
Write-Host "`n[$CurrentStep/$TotalSteps] Checking Boost.Python 3.12 libraries..." -ForegroundColor Yellow

$BoostLibDir = Join-Path $UEPath "Engine\Source\ThirdParty\Boost\Deploy\boost-1.85.0\VS2015\x64\lib"
$BoostPython312 = Join-Path $BoostLibDir "boost_python312-mt-x64.dll"

if (Test-Path $BoostPython312) {
    Write-Host "      boost_python312-mt-x64.dll found" -ForegroundColor Green
} else {
    Write-Host "      [WARN] boost_python312-mt-x64.dll not found!" -ForegroundColor Yellow
    Write-Host "      You may need to build Boost.Python from source or obtain pre-built binaries." -ForegroundColor Yellow
    Write-Host "      See: https://www.boost.org/doc/libs/1_85_0/libs/python/doc/html/building.html" -ForegroundColor Gray
}

# Step 7: Install pip
$CurrentStep++
Write-Host "`n[$CurrentStep/$TotalSteps] Installing pip..." -ForegroundColor Yellow
$GetPip = Join-Path $env:TEMP "get-pip.py"
Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $GetPip -UseBasicParsing
$Python = Join-Path $PythonDir "python.exe"
& $Python $GetPip --no-warn-script-location 2>&1 | Out-Null
Write-Host "      pip installed" -ForegroundColor Green

# Step 8: Install ROCm PyTorch
$CurrentStep++
Write-Host "`n[$CurrentStep/$TotalSteps] Installing PyTorch with ROCm (this may take a while)..." -ForegroundColor Yellow
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

# Step 9: Install ML packages
$CurrentStep++
Write-Host "`n[$CurrentStep/$TotalSteps] Installing ML packages (transformers, ultralytics)..." -ForegroundColor Yellow
& $Python -m pip install transformers ultralytics huggingface-hub 2>&1 | Out-Null
Write-Host "      ML packages installed" -ForegroundColor Green

# Final Verification
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Verifying installation..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Verify Python runtime
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

# Verify build requirements
Write-Host "`nBuild Requirements Check:" -ForegroundColor Cyan
$python312lib = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\Win64\libs\python312.lib"
$pyconfig = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\Win64\include\pyconfig.h"

if (Test-Path $python312lib) {
    Write-Host "  [OK] python312.lib exists" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] python312.lib MISSING" -ForegroundColor Red
}

if (Test-Path $pyconfig) {
    $content = Get-Content $pyconfig -Raw
    if ($content -match 'pragma comment.*python312\.lib') {
        Write-Host "  [OK] pyconfig.h references python312.lib" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] pyconfig.h does NOT reference python312.lib" -ForegroundColor Red
    }
}

if (Test-Path $BoostPython312) {
    Write-Host "  [OK] boost_python312-mt-x64.dll exists" -ForegroundColor Green
} else {
    Write-Host "  [WARN] boost_python312-mt-x64.dll missing (may need to build from source)" -ForegroundColor Yellow
}

# Step 10: Clean Python plugin intermediate files (CRITICAL - required after header update)
Write-Host "`n[CLEANUP] Removing stale Python plugin object files..." -ForegroundColor Yellow
$PythonPluginIntermediate = Join-Path $UEPath "Engine\Plugins\Experimental\PythonScriptPlugin\Intermediate\Build\Win64"
if (Test-Path $PythonPluginIntermediate) {
    Remove-Item $PythonPluginIntermediate -Recurse -Force
    Write-Host "      Removed PythonScriptPlugin intermediate files" -ForegroundColor Green
    Write-Host "      This forces recompilation with Python 3.12 headers" -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor White
Write-Host "1. Install AMD Software: PyTorch on Windows Edition 7.1.1 driver" -ForegroundColor Gray
Write-Host "   https://www.amd.com/en/support" -ForegroundColor Gray
Write-Host "2. Rebuild Unreal Engine (clean build recommended):" -ForegroundColor Gray
Write-Host "   Build.bat UnrealEditor Win64 Development" -ForegroundColor Gray
Write-Host "3. Test GPU acceleration in your Python scripts" -ForegroundColor Gray
