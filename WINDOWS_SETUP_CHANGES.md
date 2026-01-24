# Windows Setup Changes

This document explains what `WinROCmSetup.ps1` modifies in your Unreal Engine 5.7 source build.

## Overview

UE 5.7 ships with Python 3.11, but AMD's ROCm PyTorch wheels for Windows require Python 3.12. The script upgrades the embedded Python and patches Build.cs files to reference the new version.

## Files Modified

### 1. Python Runtime (Binaries)

**Location:** `Engine/Binaries/ThirdParty/Python3/Win64/`

| Before | After |
|--------|-------|
| Python 3.11.x (embeddable) | Python 3.12.8 (embeddable) |

**What's installed:**
- `python.exe` - Python executable
- `python312.dll` - Python DLL
- `python312.zip` - Compressed stdlib
- `Lib/` - Extracted standard library
- `Lib/site-packages/` - pip packages (torch, etc.)

### 2. Python Headers (Source)

**Location:** `Engine/Source/ThirdParty/Python3/Win64/include/`

The UE build system looks for Python headers here. The script downloads headers from the Python NuGet package and installs them.

**Key files:**
- `Python.h` - Main header
- `pyconfig.h` - Build configuration (contains critical `#pragma comment(lib,"python312.lib")`)
- `object.h` - Object API

**Why this matters:**

The original Python 3.11 headers contain:
```c
#pragma comment(lib,"python311.lib")  // Hardcoded in pyconfig.h!
```

This causes `LNK1104: cannot open file 'python311.lib'` during builds because the linker automatically tries to link against the old library.

### 3. Python Library (Source)

**Location:** `Engine/Source/ThirdParty/Python3/Win64/libs/`

| File | Purpose |
|------|---------|
| `python312.lib` | Import library for linking |
| `python3.lib` | Generic import library |

### 4. Build.cs Files Patched

The script patches three Build.cs files to reference Python 3.12:

#### Python3.Build.cs

**Location:** `Engine/Source/ThirdParty/Python3/Python3.Build.cs`

**Changes:**
- `python311` → `python312`
- `python3.11` → `python3.12`
- `Python311` → `Python312`

#### Boost.Build.cs

**Location:** `Engine/Source/ThirdParty/Boost/Boost.Build.cs`

**Changes:**
- `"python311"` → `"python312"`

This updates the Boost.Python library reference.

#### UnrealUSDWrapper.Build.cs

**Location:** `Engine/Plugins/Runtime/USDCore/Source/UnrealUSDWrapper/UnrealUSDWrapper.Build.cs`

**Changes:**
- `python311.dll` → `python312.dll`

### 5. Intermediate Files Cleaned

**Location:** `Engine/Plugins/Experimental/PythonScriptPlugin/Intermediate/Build/Win64/`

**Action:** Deleted

**Why:** Object files compiled with Python 3.11 headers have the `python311.lib` pragma embedded. Even after installing new headers, these stale object files would cause linker errors. Deleting them forces recompilation with the new headers.

## Packages Installed

### PyTorch + ROCm

Installed from AMD's ROCm repository (`https://repo.radeon.com/rocm/windows/rocm-rel-7.1.1`):

| Package | Version |
|---------|---------|
| torch | 2.9.0+rocmsdk20251116 |
| torchvision | 0.24.0+rocmsdk20251116 |
| rocm_sdk_core | 0.1.dev0 |
| rocm_sdk_libraries_custom | 0.1.dev0 |
| rocm | 0.1.dev0 |

### Dependencies

- filelock, typing-extensions, sympy, networkx
- jinja2, fsspec, numpy, pillow, setuptools

### ML Packages

- transformers (Hugging Face)
- ultralytics (YOLO)
- huggingface-hub

## System Requirements

### AMD Driver

You must install **AMD Software: PyTorch on Windows Edition 7.1.1** (not the regular gaming driver).

Download from: https://www.amd.com/en/support

This special driver enables ROCm/HIP support on Windows for Radeon RX 7000/9000 series GPUs.

## Backups Created

The script creates timestamped backups before making changes:

- `Engine/Binaries/ThirdParty/Python3/Win64_backup_YYYYMMDD_HHMMSS/`
- `Engine/Source/ThirdParty/Python3/Win64/include_backup_YYYYMMDD_HHMMSS/`

## Reverting Changes

### Restore Python Runtime

```powershell
$UEPath = "C:\UE_5.7"

# Find backup
Get-ChildItem "$UEPath\Engine\Binaries\ThirdParty\Python3" | Where-Object { $_.Name -like "Win64_backup*" }

# Restore
Remove-Item "$UEPath\Engine\Binaries\ThirdParty\Python3\Win64" -Recurse -Force
Rename-Item "$UEPath\Engine\Binaries\ThirdParty\Python3\Win64_backup_XXXXXXXX" "Win64"
```

### Restore Headers

```powershell
$UEPath = "C:\UE_5.7"

# Find backup
Get-ChildItem "$UEPath\Engine\Source\ThirdParty\Python3\Win64" | Where-Object { $_.Name -like "include_backup*" }

# Restore
Remove-Item "$UEPath\Engine\Source\ThirdParty\Python3\Win64\include" -Recurse -Force
Rename-Item "$UEPath\Engine\Source\ThirdParty\Python3\Win64\include_backup_XXXXXXXX" "include"
```

### Revert Build.cs Changes

Use git to restore the original files:

```powershell
cd $UEPath
git checkout -- Engine/Source/ThirdParty/Python3/Python3.Build.cs
git checkout -- Engine/Source/ThirdParty/Boost/Boost.Build.cs
git checkout -- Engine/Plugins/Runtime/USDCore/Source/UnrealUSDWrapper/UnrealUSDWrapper.Build.cs
```

## Troubleshooting

### "LNK1104: cannot open file 'python311.lib'"

The Python 3.12 headers weren't installed correctly, or stale object files exist.

1. Re-run the script with `-Force`:
   ```powershell
   .\WinROCmSetup.ps1 -UEPath "C:\UE_5.7" -Force
   ```

2. Clean intermediate files:
   ```powershell
   Remove-Item "C:\UE_5.7\Engine\Plugins\Experimental\PythonScriptPlugin\Intermediate\Build\Win64" -Recurse -Force
   ```

3. Rebuild UE

### "ROCm available: False"

1. Install **AMD Software: PyTorch on Windows Edition 7.1.1** driver
2. Restart your computer after driver installation
3. Verify GPU in Device Manager shows "AMD Radeon"

### "boost_python312-mt-x64.dll not found"

UE 5.7 ships with Boost.Python built for Python 3.11. If you need Boost.Python functionality, you may need to:

1. Build Boost.Python from source against Python 3.12
2. Or obtain pre-built binaries for Python 3.12

For most ML workflows, this isn't required.

### Flash Attention Warnings

Warnings like "Flash Efficient attention on Current AMD GPU is still experimental" are harmless. To suppress:

```powershell
$env:TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL = "1"
```

---

*Document version: 2026-01-24*
