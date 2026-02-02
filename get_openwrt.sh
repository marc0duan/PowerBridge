#!/bin/bash

# ==========================================
# OpenWrt Downloader & Converter for VMware
# ==========================================

# 1. Update and Install Dependencies
echo "[+] Updating package list and installing dependencies..."
sudo apt-get update -qq
# qemu-utils is required for the 'qemu-img' command
sudo apt-get install -y qemu-utils wget gzip grep -qq

# 2. Determine the Latest Stable Version
# We scrape the official downloads page for the highest version number
BASE_URL="https://downloads.openwrt.org/releases/"
echo "[+] Checking for the latest OpenWrt version..."

# Fetch list, filter for version numbers (YY.MM.PATCH), sort correctly, take the last one
LATEST_VER=$(curl -s $BASE_URL | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n 1)

if [ -z "$LATEST_VER" ]; then
    echo "[-] Error: Could not determine latest version. Check your internet connection."
    exit 1
fi

echo "[*] Latest version detected: $LATEST_VER"

# 3. Define File Names
# We use the x86-64 generic ext4 combined image (standard for VMs)
IMG_NAME="openwrt-${LATEST_VER}-x86-64-generic-ext4-combined.img"
GZ_NAME="${IMG_NAME}.gz"
VMDK_NAME="openwrt-${LATEST_VER}-x86-64.vmdk"
DOWNLOAD_URL="${BASE_URL}${LATEST_VER}/targets/x86/64/${GZ_NAME}"

# 4. Download
echo "[+] Downloading $GZ_NAME..."
wget -q --show-progress "$DOWNLOAD_URL"

if [ ! -f "$GZ_NAME" ]; then
    echo "[-] Download failed. URL might be incorrect: $DOWNLOAD_URL"
    exit 1
fi

# 5. Extract
echo "[+] Extracting image..."
gunzip -f "$GZ_NAME"

# 6. Convert to VMDK
echo "[+] Converting .img to .vmdk format for VMware..."
qemu-img convert -f raw -O vmdk "$IMG_NAME" "$VMDK_NAME"

# 7. Cleanup
echo "[+] Cleaning up raw image..."
rm "$IMG_NAME"

# 8. Finish
echo ""
echo "=========================================="
echo "SUCCESS! Disk image created:"
echo "$(pwd)/$VMDK_NAME"
echo "=========================================="
echo "Next Steps:"
echo "1. Copy this .vmdk file to your host machine."
echo "2. Create a new VM in VMware."
echo "3. Choose 'Use an existing virtual disk' and select this file."
