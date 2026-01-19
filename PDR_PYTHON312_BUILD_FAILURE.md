# PDR: Python 3.12 Build Failure Analysis

**Date:** 2026-01-19
**Author:** Claude (Post-Mortem Analysis)
**Severity:** CRITICAL - Blocks all UE builds
**Status:** ✅ RESOLVED (2026-01-19)

---

## Executive Summary

The `Setup-ROCm.ps1` script was missing critical steps to install Python 3.12 **development files** (headers + import library), causing Unreal Engine builds to fail with linker errors.

**Root Cause:** The script used the Python embeddable distribution which only contains runtime files, not development files needed for C++ compilation.

**Solution:** Updated `Setup-ROCm.ps1` to download Python 3.12 headers and `python312.lib` from the official NuGet package.

---

## Problem Statement

After running the original `Setup-ROCm.ps1`, attempting to build any UE project failed with:

```
LINK : fatal error LNK1104: cannot open file 'python311.lib'
```

---

## Root Cause Analysis

### The Issue: Mismatched Headers

The original script installed:
- ✅ Python 3.12.8 **runtime** (python312.dll, python.exe)
- ❌ Python 3.11 **headers** (still in place from original UE 5.7)

The Python 3.11 `pyconfig.h` header contains:
```c
#pragma comment(lib,"python311.lib")  // ← Hardcoded!
```

This MSVC pragma tells the linker to automatically link against `python311.lib`, which doesn't exist.

### Missing Components

| Component | Required Location | Original Script | Fixed Script |
|-----------|------------------|-----------------|--------------|
| `python312.dll` | `Engine/Binaries/ThirdParty/Python3/Win64/` | ✅ | ✅ |
| `pyconfig.h` (3.12) | `Engine/Source/ThirdParty/Python3/Win64/include/` | ❌ Had 3.11 | ✅ |
| `python312.lib` | `Engine/Source/ThirdParty/Python3/Win64/libs/` | ❌ | ✅ |

---

## Solution Applied

### Fix: Install Python 3.12 Development Files

Added **Step 4** to `Setup-ROCm.ps1`:

```powershell
# Step 4: Download and install Python 3.12 development files
$NugetUrl = "https://www.nuget.org/api/v2/package/python/3.12.8"
$NugetPkg = Join-Path $env:TEMP "python312-nuget.nupkg"
$NugetExtract = Join-Path $env:TEMP "python312-nuget"

# Download NuGet package
Invoke-WebRequest -Uri $NugetUrl -OutFile $NugetPkg -UseBasicParsing

# Extract
Expand-Archive -Path $NugetPkg -DestinationPath $NugetExtract -Force

$SourceInclude = Join-Path $NugetExtract "tools\include"
$SourceLibs = Join-Path $NugetExtract "tools\libs"

# Install headers
$TargetIncludeWin64 = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\Win64\include"
Copy-Item -Path $SourceInclude -Destination $TargetIncludeWin64 -Recurse -Force

# Install import library
$TargetLibsWin64 = Join-Path $UEPath "Engine\Source\ThirdParty\Python3\Win64\libs"
Copy-Item -Path (Join-Path $SourceLibs "python312.lib") -Destination $TargetLibsWin64 -Force
```

### Verification

After the fix, `pyconfig.h` now contains:
```c
#pragma comment(lib,"python312.lib")  // ✅ Correct!
```

---

## Verification Checklist

- [x] `python312.lib` exists in `Engine/Source/ThirdParty/Python3/Win64/libs/`
- [x] `pyconfig.h` contains `#pragma comment(lib,"python312.lib")`
- [x] `Boost.Build.cs` contains `"python312"` (not `"python311"`)
- [x] `boost_python312-mt-x64.dll` exists and depends on `python312.dll`
- [x] UE project builds successfully (verified 2026-01-19)
- [x] Python scripts run in Editor

**Note:** After updating headers, you MUST clean the PythonScriptPlugin intermediate files:
```
Engine\Plugins\Experimental\PythonScriptPlugin\Intermediate\Build\Win64\
```
Otherwise stale object files will still contain `#pragma comment(lib,"python311.lib")`.

---

## Updated Script Steps

The fixed `Setup-ROCm.ps1` now has 9 steps:

1. **Backup existing Python runtime**
2. **Download Python 3.12 embeddable**
3. **Install Python 3.12 runtime**
4. **Install Python 3.12 development files (headers + libs)** ← NEW!
5. **Patch Engine Build.cs files**
6. **Verify Boost.Python 3.12 libraries**
7. **Install pip**
8. **Install ROCm PyTorch**
9. **Install ML packages**

---

## Lessons Learned

1. **Embeddable != Development**: Python's embeddable distribution is for deployment, not building. For C++ integration, always use headers from the full installer or NuGet package.

2. **Header Version Matching**: When upgrading Python versions, headers MUST match the runtime version due to hardcoded `#pragma comment(lib)` directives.

3. **Verify Build Requirements**: Always verify all build-time dependencies exist before claiming setup is complete.

---

## Files Modified

1. `Setup-ROCm.ps1` - Added Step 4 (header/lib installation) and verification checks
2. `install_python312_headers.ps1` - Standalone script for header installation (created)
3. `README.md` - Updated to document build requirements

---

*PDR Closed: 2026-01-19*
