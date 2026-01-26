# Linux Setup Changes

This document explains what `LinuxROCmSetup.sh` modifies in your Unreal Engine 5.7 source build.

## Overview

UE 5.7 ships with Python 3.11, but AMD's ROCm PyTorch wheels require Python 3.12. Additionally, the UE build system on Linux has issues linking Python correctly for USD plugins.

## Files Modified

### 1. Python Runtime (Binaries)

**Location:** `Engine/Binaries/ThirdParty/Python3/Linux/`

| Before | After |
|--------|-------|
| Python 3.11.x | Python 3.12.8 |
| Stock UE distribution | Custom build with shared libs |

**What's installed:**
- `bin/python3` - Python executable
- `lib/libpython3.12.so.1.0` - Shared library
- `lib/python3.12/` - Standard library
- `include/python3.12/` - Development headers

### 2. Python Headers (Source)

**Location:** `Engine/Source/ThirdParty/Python3/Linux/include/`

The UE build system looks for Python headers here, not in Binaries. The script copies:

```
Engine/Binaries/.../include/python3.12/*
    → Engine/Source/.../Linux/include/
```

**Key files:**
- `Python.h` - Main header
- `pyconfig.h` - Build configuration
- `object.h` - Object API (references `_Py_NoneStruct`, etc.)

### 3. Python Library (Source)

**Location:** `Engine/Source/ThirdParty/Python3/Linux/lib/libpython3.12.so`

**Critical:** This must be an actual file, not a symlink. The UE linker uses relative paths that break with symlinks.

```
Engine/Binaries/.../lib/libpython3.12.so.1.0
    → Engine/Source/.../Linux/lib/libpython3.12.so (copied, not linked)
```

### 4. Editor Launcher Script (NEW)

**Location:** `Engine/Binaries/Linux/UnrealEditor.sh`

**Purpose:** Ensures UE's embedded Python 3.12 is loaded instead of the system Python.

**Why it's needed:**

When both UE's Python 3.12.8 and system Python 3.12.x are present, the dynamic linker may load the wrong library at runtime, causing `Py_InitializeFromConfig` to fail with "Python could not be initialized and was disabled".

**How it works:**

1. Sets `LD_PRELOAD` to force-load UE's `libpython3.12.so.1.0` before any other libraries
2. Prepends UE's Python lib path to `LD_LIBRARY_PATH`
3. Sets `UE_PYTHON_DIR` for UE's internal Python detection
4. Clears `PYTHONHOME` and `PYTHONPATH` to prevent conflicts
5. Adds ROCm paths if `/opt/rocm` exists

**IMPORTANT:** Always use `UnrealEditor.sh` to launch the editor, not `UnrealEditor` directly:

```bash
# Correct
./UnrealEditor.sh /path/to/Project.uproject

# Wrong (may cause Python initialization failure)
./UnrealEditor /path/to/Project.uproject
```

### 5. UnrealUSDWrapper.Build.cs

**Location:** `Engine/Plugins/Runtime/USDCore/Source/UnrealUSDWrapper/UnrealUSDWrapper.Build.cs`

**Problem:** The original file references `python3.11` and doesn't explicitly link the Python library on Linux, causing undefined symbol errors like:

```
ld.lld: error: undefined symbol: _Py_NoneStruct
ld.lld: error: undefined symbol: PyBool_FromLong
```

**Changes made:**

1. Replace `python3.11` → `python3.12` references
2. Add explicit library linking:

```csharp
// BEFORE (around line 113-115):
PublicSystemLibraryPaths.Add(Path.Combine(PythonBinaryTPSDir, "lib"));
PrivateRuntimeLibraryPaths.Add(Path.Combine(PythonBinaryTPSDir, "bin"));
RuntimeDependencies.Add(Path.Combine(PythonBinaryTPSDir, "bin", "python3.11"));

// AFTER:
PublicSystemLibraryPaths.Add(Path.Combine(PythonBinaryTPSDir, "lib"));
// Link against Python 3.12 library (added by LinuxROCmSetup.sh)
PublicAdditionalLibraries.Add(Path.Combine(PythonSourceTPSDir, "lib", "libpython3.12.so"));
PrivateRuntimeLibraryPaths.Add(Path.Combine(PythonBinaryTPSDir, "bin"));
RuntimeDependencies.Add(Path.Combine(PythonBinaryTPSDir, "lib", "libpython3.12.so.1.0"));
```

**Why this fix is needed:**

The original code adds library *paths* but not the actual library to link. On Windows, the Python3 module dependency handles this. On Linux, the module filtering ("Not under compatible directories") prevents proper dependency resolution, so we need explicit linking.

## System Changes

### ROCm Repository

**Added:** `/etc/apt/sources.list.d/rocm.list`

```
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.2 noble main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/7.2/ubuntu noble main
```

### ROCm Packages Installed

- `rocm-dev` - Development files
- `rocm-utils` - Utilities
- `rocminfo` - GPU info tool
- `rocm-smi` - System management
- `hipblas` - BLAS library
- `miopen-hip` - Deep learning primitives

### Environment Variables

**Added:** `/etc/profile.d/rocm.sh`

```bash
export ROCM_PATH=/opt/rocm
export HIP_PATH=/opt/rocm
export PATH=$PATH:/opt/rocm/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/lib64
```

### User Groups

User added to `render` and `video` groups (required for GPU access).

## Backups Created

The script creates timestamped backups before making changes:

- `Engine/Binaries/ThirdParty/Python3/Linux_backup_YYYYMMDD_HHMMSS/`
- `UnrealUSDWrapper.Build.cs.backup_YYYYMMDD_HHMMSS`

## Reverting Changes

### Restore Python 3.11

```bash
UE_ROOT="/path/to/UE_5.7"

# Find backup
ls ${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/ | grep backup

# Restore
rm -rf ${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux
mv ${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux_backup_XXXXXXXX \
   ${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux
```

### Restore Build.cs

```bash
USD_DIR="${UE_ROOT}/Engine/Plugins/Runtime/USDCore/Source/UnrealUSDWrapper"

# Find backup
ls ${USD_DIR}/*.backup_*

# Restore
cp ${USD_DIR}/UnrealUSDWrapper.Build.cs.backup_XXXXXXXX \
   ${USD_DIR}/UnrealUSDWrapper.Build.cs
```

### Remove ROCm

```bash
sudo apt remove rocm-dev rocm-utils rocminfo rocm-smi hipblas miopen-hip
sudo rm /etc/apt/sources.list.d/rocm.list
sudo rm /etc/apt/preferences.d/rocm-pin-600
sudo rm /etc/profile.d/rocm.sh
```

## Troubleshooting

### Build fails with "undefined symbol: _Py_NoneStruct"

The Python library isn't being linked. Check:

1. Library exists: `ls Engine/Source/ThirdParty/Python3/Linux/lib/libpython3.12.so`
2. It's a file, not symlink: `file Engine/Source/.../libpython3.12.so`
3. Build.cs was patched: `grep "libpython3.12.so" Engine/Plugins/.../UnrealUSDWrapper.Build.cs`

### Build fails with "cannot open libpython3.12.so"

The library path is wrong. Ensure:
- The file is copied (not symlinked) to `Engine/Source/.../lib/`
- Regenerate project files after changes: `./GenerateProjectFiles.sh`

### PyTorch doesn't detect GPU

1. Reboot after running setup (group membership requires logout)
2. Check ROCm: `rocminfo | grep "Marketing Name"`
3. Check HIP: `/opt/rocm/bin/hipconfig --version`

### "Python could not be initialized and was disabled"

This error occurs when UE loads the system Python library instead of UE's embedded Python.

**Solution:** Always use the launcher script:

```bash
# Use UnrealEditor.sh, NOT UnrealEditor
./Engine/Binaries/Linux/UnrealEditor.sh /path/to/Project.uproject
```

**Why this happens:**

When system Python 3.12 is installed (e.g., via `apt install python3.12`), the dynamic linker finds `/lib/x86_64-linux-gnu/libpython3.12.so.1.0` before UE's library. The launcher script uses `LD_PRELOAD` to force UE's library to load first.

**Verify fix is working:**

```bash
# Should show UE's Python path
ldd Engine/Plugins/Experimental/PythonScriptPlugin/Binaries/Linux/libUnrealEditor-PythonScriptPlugin.so | grep python

# With LD_PRELOAD set (via launcher script):
# libpython3.12.so.1.0 => /path/to/UE_5.7/Engine/Binaries/ThirdParty/Python3/Linux/lib/libpython3.12.so.1.0

# Without LD_PRELOAD (wrong):
# libpython3.12.so.1.0 => /lib/x86_64-linux-gnu/libpython3.12.so.1.0
```

---

*Document version: 2026-01-26*
