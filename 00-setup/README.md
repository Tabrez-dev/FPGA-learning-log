# Day 0: Environment Setup (Linux)

## Goal
Setting up iCEStudio and the custom "Soan-Papdi" board toolchain on Ubuntu.

## Issues & Fixes
1. **Dependency Hell:** `grunt-wget` required ancient dependencies.
   - *Fix:* Used `npm install --legacy-peer-deps`.
2. **Toolchain Error:** The internal installer failed to download `oss-cad-suite`.
   - *Fix:* Manually created a python venv and installed `apio==0.9.5` (downgraded from 1.2.1).
3. **Hardware Invisible:** The board wasn't showing up in `lsusb`.
   - *Fix:* Replaced the USB-C cable (original was power-only).
4. **Permissions:** `dmesg` showed the device, but iCEStudio couldn't access it.
   - *Fix:* Added udev rules for vendor `1d50`.

## Key Commands
```bash
# Installing the toolchain manually
APIO_HOME_DIR=~/.icestudio/apio ~/.icestudio/venv/bin/apio install --all

# Checking kernel logs for USB connection
sudo dmesg -w
