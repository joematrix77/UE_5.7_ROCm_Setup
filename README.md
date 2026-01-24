# Unreal Engine 5.7 ROCm Setup

Upgrade Unreal Engine 5.7's embedded Python to enable **GPU-accelerated machine learning** on AMD Radeon GPUs using ROCm.

## What This Does

These setup scripts upgrade UE 5.7's Python from 3.11 to 3.12 and install:

| Package | Version | Purpose |
|---------|---------|---------|
| Python | 3.12.8 | Required for ROCm wheels |
| PyTorch | 2.9.0+rocm | Deep learning framework |
| ROCm SDK | 7.1.1 (Win) / 7.2 (Linux) | AMD GPU compute |
| transformers | latest | Hugging Face models (CLIP, etc.) |

## Supported Platforms

| Platform | Script | Status |
|----------|--------|--------|
| **Windows 11** | `Setup-ROCm.ps1` | ✅ Tested |
| **Ubuntu 24.04** | `LinuxROCmSetup.sh` | ✅ Tested |

## Supported Hardware

- **GPUs:** AMD Radeon RX 7000 series, RX 9000 series (RDNA 3/4)
- **APUs:** Select Ryzen AI 300 series
- **OS:** Windows 11, Ubuntu 24.04 LTS (Noble)

## Prerequisites

### All Platforms

1. **Unreal Engine 5.7 Source Build**
   - You need [GitHub access to Unreal Engine](https://www.unrealengine.com/ue-on-github)
   - Clone and build UE 5.7 at least once

### Windows

2. **AMD Graphics Driver**
   - Install [AMD Software: PyTorch on Windows Edition 7.1.1](https://www.amd.com/en/support)
   - This is a special driver that enables ROCm on Windows

### Linux (Ubuntu)

2. **No special driver needed** - The script installs ROCm 7.2 from AMD's repository

---

## Installation (Windows)

### Step 1: Clone This Repository

```bash
git clone https://github.com/joematrix77/UE_5.7_ROCm_Setup.git
cd UE_5.7_ROCm_Setup
```

### Step 2: Run the Setup Script

```powershell
# Replace with your UE 5.7 source path
.\Setup-ROCm.ps1 -UEPath "C:\UnrealEngine-5.7"
```

The script automatically handles everything:

| Step | Action | Details |
|------|--------|---------|
| 1 | Backup Python runtime | Copies existing `Win64/` to `Win64_backup_YYYYMMDD/` |
| 2 | Download Python 3.12 | Fetches embeddable distribution from python.org |
| 3 | Install Python runtime | Extracts to `Engine/Binaries/ThirdParty/Python3/Win64/` |
| 4 | **Install dev files** | Downloads NuGet package, installs headers + `python312.lib` |
| 5 | Patch Build.cs files | Updates `Python3.Build.cs`, `Boost.Build.cs`, `UnrealUSDWrapper.Build.cs` |
| 6 | Verify Boost.Python | Checks `boost_python312-mt-x64.dll` exists |
| 7 | Install pip | Downloads and runs `get-pip.py` |
| 8 | Install PyTorch + ROCm | Installs wheels from AMD's ROCm repository |
| 9 | Install ML packages | Installs transformers, ultralytics, huggingface-hub |
| 10 | **Clean stale objects** | Removes `PythonScriptPlugin/Intermediate/` to force recompile |

**Why Step 4 & 10 are critical:**

UE 5.7 ships with Python 3.11 headers containing:
```c
#pragma comment(lib,"python311.lib")  // Hardcoded in pyconfig.h!
```

This causes `LNK1104: cannot open file 'python311.lib'` during builds. The script:
- Replaces headers with Python 3.12 versions (references `python312.lib`)
- Cleans old object files that have the `python311.lib` pragma embedded

After running the script, rebuild UE and the error is gone

### Optional Parameters

```powershell
# Skip backup (if you've already backed up)
.\Setup-ROCm.ps1 -UEPath "C:\UE_5.7" -SkipBackup

# Force reinstall even if Python 3.12 is detected
.\Setup-ROCm.ps1 -UEPath "C:\UE_5.7" -Force
```

---

## Installation (Linux)

### Step 1: Clone This Repository

```bash
git clone https://github.com/joematrix77/UE_5.7_ROCm_Setup.git
cd UE_5.7_ROCm_Setup
```

### Step 2: Run the Setup Script

```bash
# Replace with your UE 5.7 source path
chmod +x LinuxROCmSetup.sh
./LinuxROCmSetup.sh --ue-path /path/to/UE_5.7
```

Or set via environment variable:

```bash
export UE_ROOT=/path/to/UE_5.7
./LinuxROCmSetup.sh
```

The script automatically handles everything:

| Step | Action | Details |
|------|--------|---------|
| 1 | Install dependencies | Build tools, dev libraries |
| 2 | Backup Python runtime | Copies existing `Linux/` to `Linux_backup_YYYYMMDD/` |
| 3 | Build Python 3.12.8 | Compiles from source with shared libs + LTO |
| 4 | Setup headers | Copies to `Engine/Source/ThirdParty/Python3/Linux/include/` |
| 5 | Setup library | Copies `libpython3.12.so` (as file, not symlink) |
| 6 | Patch Build.cs | Updates `UnrealUSDWrapper.Build.cs` for explicit linking |
| 7 | Add user to groups | Adds to `render` and `video` groups for GPU access |
| 8 | Install ROCm 7.2 | Adds AMD repository, installs rocm-dev, hipblas, etc. |
| 9 | Install PyTorch | Installs torch/torchvision from ROCm 7.2 wheels |
| 10 | Verify | Tests Python, headers, library, and PyTorch GPU detection |

**Why the Build.cs patch is critical:**

On Linux, UE's USD plugin adds Python library *paths* but doesn't actually link the library. This causes undefined symbol errors:

```
ld.lld: error: undefined symbol: _Py_NoneStruct
ld.lld: error: undefined symbol: PyBool_FromLong
```

The script adds explicit library linking to fix this. See [LINUX_SETUP_CHANGES.md](LINUX_SETUP_CHANGES.md) for full details.

### Optional Parameters

```bash
# Skip Python installation (ROCm only)
./LinuxROCmSetup.sh --skip-python

# Skip ROCm installation (Python only)
./LinuxROCmSetup.sh --skip-rocm

# Show help
./LinuxROCmSetup.sh --help
```

### After Installation

```bash
# REBOOT (required for group membership)
sudo reboot

# Then regenerate UE project files
cd /path/to/UE_5.7
./GenerateProjectFiles.sh

# Build UE Editor
make UnrealEditor-Linux-Development -j$(nproc)
```

---

## Verification

After setup, verify your GPU is detected:

```python
# Run in UE's Python environment
import torch
print(f"PyTorch: {torch.__version__}")
print(f"ROCm available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0)}")
```

Expected output:
```
PyTorch: 2.9.0+rocmsdk20251116
ROCm available: True
GPU: AMD Radeon RX 9060 XT
```

## Tested Configurations

### Windows

| Component | Version/Model |
|-----------|---------------|
| GPU | AMD Radeon RX 9060 XT 16GB (RDNA 4) |
| OS | Windows 11 |
| Driver | AMD Software: PyTorch on Windows Edition 7.1.1 |
| UE | 5.7 Source Build |

### Linux

| Component | Version/Model |
|-----------|---------------|
| GPU | AMD Radeon RX 9060 XT 16GB (RDNA 4) |
| OS | Ubuntu 24.04 LTS (Noble) |
| Kernel | 6.18.x |
| ROCm | 7.2 |
| UE | 5.7 Source Build |

### Verified ML Workloads
- Depth Anything V2 (monocular depth estimation)
- Florence-2 (vision-language model)
- CLIP (vision-language model)
- YOLO v8 (object detection)

## Troubleshooting

### "LNK1104: cannot open file 'python311.lib'"
This means the Python 3.12 headers weren't installed correctly. Run:
```powershell
.\Setup-ROCm.ps1 -UEPath "C:\UE_5.7" -Force
```
Then clean and rebuild:
```powershell
Remove-Item "C:\UE_5.7\Engine\Plugins\Experimental\PythonScriptPlugin\Intermediate\Build\Win64" -Recurse -Force
# Rebuild UE
```

### "ROCm available: False"
- Make sure you installed the AMD PyTorch driver (not the regular gaming driver)
- Restart your computer after driver installation
- Check Device Manager for "AMD Radeon" under Display adapters

### Flash Attention Warnings
You may see warnings like:
```
Flash Efficient attention on Current AMD GPU is still experimental
```
These are harmless. To suppress, set:
```
TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
```

### Reverting to Original Python (Windows)
Your original Python is backed up. To revert:
```powershell
# Find your backup
ls Engine\Binaries\ThirdParty\Python3\ | Where-Object { $_.Name -like "Win64_backup*" }

# Restore
Remove-Item Engine\Binaries\ThirdParty\Python3\Win64 -Recurse -Force
Rename-Item Engine\Binaries\ThirdParty\Python3\Win64_backup_XXXXXXXX Win64
```

### Linux: "undefined symbol: _Py_NoneStruct"
The Python library isn't being linked. Check:
1. Library exists: `ls Engine/Source/ThirdParty/Python3/Linux/lib/libpython3.12.so`
2. It's a file, not symlink: `file Engine/Source/ThirdParty/Python3/Linux/lib/libpython3.12.so`
3. Build.cs was patched: `grep "libpython3.12.so" Engine/Plugins/Runtime/USDCore/Source/UnrealUSDWrapper/UnrealUSDWrapper.Build.cs`

Re-run the script with `--skip-rocm` to re-apply fixes without reinstalling ROCm.

### Linux: PyTorch doesn't detect GPU
1. **Reboot** after running setup (group membership requires logout)
2. Check ROCm: `rocminfo | grep "Marketing Name"`
3. Check HIP: `/opt/rocm/bin/hipconfig --version`
4. Verify group membership: `groups` (should show `render` and `video`)

### Linux: Reverting to Original Python
```bash
UE_ROOT="/path/to/UE_5.7"

# Find backup
ls ${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/ | grep backup

# Restore
rm -rf ${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux
mv ${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux_backup_XXXXXXXX \
   ${UE_ROOT}/Engine/Binaries/ThirdParty/Python3/Linux
```

See [LINUX_SETUP_CHANGES.md](LINUX_SETUP_CHANGES.md) for complete revert instructions.

## Why Python 3.12?

AMD's official ROCm PyTorch wheels for Windows are only built for Python 3.12. The stock UE 5.7 ships with Python 3.11, which is incompatible.

## References

- [AMD ROCm Installation Guide](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/windows/install-pytorch.html)
- [PyTorch ROCm Wheels](https://repo.radeon.com/rocm/windows/)
- [Unreal Engine GitHub Access](https://www.unrealengine.com/ue-on-github)

## License

This setup script is provided as-is under MIT License. Unreal Engine itself is subject to Epic Games' license terms.

## Credits

- **Epic Games** - Unreal Engine
- **AMD** - ROCm SDK and PyTorch wheels
- **Joe Castro / Matrix Networx** - Setup script and testing

---

*Last updated: 2026-01-24*
