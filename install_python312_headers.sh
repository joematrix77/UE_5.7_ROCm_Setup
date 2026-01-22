#!/bin/bash

# 1. Update package lists
echo "Updating package lists..."
sudo apt update

# 2. Install Python 3.12 Header Files and Development Tools
# On Ubuntu 24.04, these provide the 'include' and 'lib' files UE needs
echo "Installing Python 3.12 dev headers..."
sudo apt install -y python3.12-dev python3.12-venv libpython3.12-dev

# 3. Verify installation path
# Unreal Engine 5.7 on Linux looks for headers in /usr/include/python3.12
if [ -f "/usr/include/python3.12/Python.h" ]; then
    echo "Success: Python 3.12 headers found at /usr/include/python3.12"
else
    echo "Error: Headers not found. Ensure python3.12-dev installed correctly."
    exit 1
fi

# 4. Optional: Set as default for the shell session
export UE_PYTHON_DIR="/usr"
echo "Environment variable UE_PYTHON_DIR set to $UE_PYTHON_DIR"
