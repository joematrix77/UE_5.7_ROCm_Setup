# Install Python 3.12 headers for UE 5.7
# This fixes the LNK1104: cannot open file 'python311.lib' error

param(
    [string]$UEPath = "S:\UE_5.7"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installing Python 3.12 Headers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$NugetPkg = Join-Path $env:TEMP "python312-nuget.nupkg"
$ExtractDir = Join-Path $env:TEMP "python312-nuget"

# Download if not exists
if (!(Test-Path $NugetPkg)) {
    Write-Host "Downloading Python 3.12 NuGet package..." -ForegroundColor Yellow
    $NugetUrl = "https://www.nuget.org/api/v2/package/python/3.12.8"
    Invoke-WebRequest -Uri $NugetUrl -OutFile $NugetPkg -UseBasicParsing
}

# Extract
Write-Host "Extracting NuGet package..." -ForegroundColor Yellow
if (Test-Path $ExtractDir) { Remove-Item $ExtractDir -Recurse -Force }
Expand-Archive -Path $NugetPkg -DestinationPath $ExtractDir -Force

# Find include directory
$SourceInclude = Join-Path $ExtractDir "tools\include"
if (!(Test-Path $SourceInclude)) {
    Write-Host "ERROR: Include directory not found at $SourceInclude" -ForegroundColor Red
    Write-Host "Available directories:" -ForegroundColor Yellow
    Get-ChildItem $ExtractDir -Recurse -Directory | ForEach-Object { Write-Host $_.FullName }
    exit 1
}

Write-Host "Source include: $SourceInclude" -ForegroundColor Green

# Target directories
$TargetIncludeWin64 = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\Win64\include"
$TargetIncludeArm64 = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\WinArm64\include"

# Backup existing
$BackupSuffix = Get-Date -Format "yyyyMMdd_HHmmss"
if (Test-Path $TargetIncludeWin64) {
    $BackupWin64 = "${TargetIncludeWin64}_backup_${BackupSuffix}"
    Write-Host "Backing up Win64 include to: $BackupWin64" -ForegroundColor Yellow
    Rename-Item $TargetIncludeWin64 $BackupWin64
}

if (Test-Path $TargetIncludeArm64) {
    $BackupArm64 = "${TargetIncludeArm64}_backup_${BackupSuffix}"
    Write-Host "Backing up WinArm64 include to: $BackupArm64" -ForegroundColor Yellow
    Rename-Item $TargetIncludeArm64 $BackupArm64
}

# Copy new headers
Write-Host "Installing Python 3.12 headers to Win64..." -ForegroundColor Yellow
Copy-Item -Path $SourceInclude -Destination $TargetIncludeWin64 -Recurse -Force

Write-Host "Installing Python 3.12 headers to WinArm64..." -ForegroundColor Yellow
Copy-Item -Path $SourceInclude -Destination $TargetIncludeArm64 -Recurse -Force

# Verify
$PyConfigWin64 = Join-Path $TargetIncludeWin64 "pyconfig.h"
$PatchLevelWin64 = Join-Path $TargetIncludeWin64 "patchlevel.h"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (Test-Path $PatchLevelWin64) {
    $version = Select-String -Path $PatchLevelWin64 -Pattern 'PY_VERSION\s+"([^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value }
    Write-Host "Python version in headers: $version" -ForegroundColor Green
}

if (Test-Path $PyConfigWin64) {
    $libRef = Select-String -Path $PyConfigWin64 -Pattern 'pragma comment.*python\d+\.lib' | ForEach-Object { $_.Line.Trim() }
    Write-Host "Library reference: $libRef" -ForegroundColor Green
}

Write-Host "`nDone! Python 3.12 headers installed." -ForegroundColor Green
Write-Host "You can now rebuild Unreal Engine." -ForegroundColor White
