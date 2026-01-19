# Unreal Engine 5.7 ROCm Setup

Upgrade Unreal Engine 5.7's embedded Python to enable **GPU-accelerated machine learning** on AMD Radeon GPUs using ROCm.

## What This Does

This setup script upgrades UE 5.7's Python from 3.11 to 3.12 and installs:

| Package | Version | Purpose |
|---------|---------|---------|
| Python | 3.12.8 | Required for ROCm wheels |
| PyTorch | 2.9.0+rocmsdk | Deep learning framework |
| ROCm SDK | 7.1.1 | AMD GPU compute |
| transformers | 4.57.6 | Hugging Face models (CLIP, etc.) |
| ultralytics | 8.4.6 | YOLO object detection |

## Supported Hardware

- **GPUs:** AMD Radeon RX 7000 series, RX 9000 series (RDNA 3/4)
- **APUs:** Select Ryzen AI 300 series
- **OS:** Windows 11 (recommended), Windows 10 (may work)

## Prerequisites

1. **Unreal Engine 5.7 Source Build**
   - You need [GitHub access to Unreal Engine](https://www.unrealengine.com/ue-on-github)
   - Clone and build UE 5.7 at least once

2. **AMD Graphics Driver**
   - Install [AMD Software: PyTorch on Windows Edition 7.1.1](https://www.amd.com/en/support)
   - This is a special driver that enables ROCm on Windows

## Installation

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

The script will:
1. Backup your existing Python installation
2. Download and install Python 3.12.8
3. Install PyTorch with ROCm support
4. Install ML dependencies (transformers, ultralytics, etc.)
5. Verify GPU detection

### Optional Parameters

```powershell
# Skip backup (if you've already backed up)
.\Setup-ROCm.ps1 -UEPath "C:\UE_5.7" -SkipBackup

# Force reinstall even if Python 3.12 is detected
.\Setup-ROCm.ps1 -UEPath "C:\UE_5.7" -Force
```

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

## Tested Configuration

| Component | Version/Model |
|-----------|---------------|
| GPU | AMD Radeon RX 9060 XT 16GB (RDNA 4) |
| OS | Windows 11 |
| Driver | AMD Software: PyTorch on Windows Edition 7.1.1 |
| UE | 5.7 Source Build |

### Verified ML Workloads
- Depth Anything V2 (monocular depth estimation)
- CLIP (vision-language model)
- YOLO v8 (object detection)

## Troubleshooting

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

### Reverting to Original Python
Your original Python is backed up. To revert:
```powershell
# Find your backup
ls Engine\Binaries\ThirdParty\Python3\ | Where-Object { $_.Name -like "Win64_backup*" }

# Restore
Remove-Item Engine\Binaries\ThirdParty\Python3\Win64 -Recurse -Force
Rename-Item Engine\Binaries\ThirdParty\Python3\Win64_backup_XXXXXXXX Win64
```

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

*Last updated: 2026-01-19*
