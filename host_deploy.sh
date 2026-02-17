#!/bin/bash

# AVP Host Deployment Script
# Usage: ./host_deploy.sh [REMOTE_IP] [USER]

# Load .env if present
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    . "${SCRIPT_DIR}/.env"
    set +a
fi

REMOTE_HOST="${1:-${DEVICE_IP:-192.168.1.1}}"
REMOTE_USER="${2:-${DEVICE_USER:-root}}"
BUNDLE_DIR="avp_bundle"
BUNDLE_TAR="avp_bundle.tar.gz"
REMOTE_DIR="/tmp/avp_bundle"

echo "AVP Bundle Deployment Tool"
echo "--------------------------"

# 1. Create Tarball
echo "Creating bundle tarball..."

#copy relevant files to bundle directory
mapfile -t PACKAGES < <(find bin/packages -name "*.ipk" | grep -E "basicstation|lora|mbedtls|sx1302")
rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}"
for PKG in "${PACKAGES[@]}"; do
    cp "$PKG" "${BUNDLE_DIR}/"
done

#making the install script
cat > "${BUNDLE_DIR}/install.sh" << 'EOF'
#!/bin/sh

# BasicStation and LoRa components
echo "Installing BasicStation and LoRa components..."
opkg remove --force-depends lora-basicstation
opkg remove --force-depends vuci-app-basicstation-api
opkg remove --force-depends vuci-app-basicstation-ui
opkg remove --force-depends sx1302_hal-utils
opkg remove --force-depends libmbedtls21

opkg install --force-maintainer libmbedtls21_*.ipk
opkg install --force-maintainer sx1302_hal-utils_*.ipk
opkg install --force-maintainer lora-basicstation_*.ipk
opkg install --force-maintainer vuci-app-basicstation-api_*.ipk
opkg install --force-maintainer vuci-app-basicstation-ui_*.ipk

echo "Installation complete!"
EOF
chmod +x "${BUNDLE_DIR}/install.sh"


tar -czf "${BUNDLE_TAR}" -C "." "${BUNDLE_DIR}"

# 2. Transfer to Device
echo "Transferring bundle to ${REMOTE_USER}@${REMOTE_HOST}..."
sshpass -e scp -o StrictHostKeyChecking=no "${BUNDLE_TAR}" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/"

# 3. Remote Install
echo "Executing remote installation..."
sshpass -e ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" << EOF
    mkdir -p ${REMOTE_DIR}
    tar -xzf /tmp/${BUNDLE_TAR} -C /tmp/
    cd ${REMOTE_DIR}
    chmod +x install.sh
    sh ./install.sh
    rm -rf ${REMOTE_DIR}
    rm /tmp/${BUNDLE_TAR}
EOF

if [ $? -eq 0 ]; then
    echo "--------------------------"
    echo "✅ Deployment and installation successful!"
else
    echo "--------------------------"
    echo "❌ Deployment failed!"
    exit 1
fi
