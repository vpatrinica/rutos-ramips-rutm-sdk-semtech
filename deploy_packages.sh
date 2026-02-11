#!/bin/bash

# Configuration
REMOTE_HOST="${1:-192.168.1.1}"
REMOTE_USER="${2:-root}"
REMOTE_DIR="/home/admin/avp-packages"

# Find all matching IPK files
mapfile -t PACKAGES < <(find bin/packages -name "*.ipk" | grep -E "basicstation|lora|mbedtls|sx1302|python3-pyopenssl|python3-pyserial|python3-requests|python3-ubus|python3-uci|python3-pymodbus|pahomqtt|python3-six|python3-cryptography|python3-bcrypt|python3-paramiko|libsodium|python3-cffi|python3-pycparser|python3-ply|python3-certifi|python3-chardet|python3-idna|python3-urllib3|python3-base|python3-light|python3-email|python3-logging|python3-urllib|python3-openssl|python3-ctypes|python3-multiprocessing|python3-decimal|python3-asyncio|python3-uuid|python3-xml|python3-codecs")

if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "No matching packages found."
    exit 1
fi

echo "Found ${#PACKAGES[@]} packages to transfer:"
for PKG in "${PACKAGES[@]}"; do
    echo "  - $(basename "$PKG")"
done
echo ""

# Create remote directory
echo "Creating remote directory..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"

# Transfer all files in single scp call
echo "Transferring all packages to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}..."
scp "${PACKAGES[@]}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ All packages transferred successfully!"
    echo ""
    echo "To install on device, run:"
    echo "  ssh ${REMOTE_USER}@${REMOTE_HOST}"
    echo "  cd ${REMOTE_DIR}"
    echo "  opkg install libmbedtls21_*.ipk"
    echo "  opkg install sx1302_hal-utils_*.ipk"
    echo "  opkg install lora-basicstation_*.ipk"
    echo "  opkg install python3-six_*.ipk"
    echo "  opkg install python3-pyopenssl_*.ipk"
    echo "  opkg install python3-pyserial_*.ipk"
    echo "  opkg install python3-requests_*.ipk"
    echo "  opkg install python3-ubus_*.ipk"
    echo "  opkg install python3-uci_*.ipk"
    echo "  opkg install python3-pymodbus_*.ipk"
    echo "  opkg install python3-pahomqtt_*.ipk"
    echo "  opkg install vuci-app-basicstation-api_*.ipk"
    echo "  opkg install vuci-app-basicstation-ui_*.ipk"
else
    echo "❌ Transfer failed!"
    exit 1
fi
