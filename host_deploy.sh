#!/bin/bash

# AVP Host Deployment Script
# Usage: ./host_deploy.sh [REMOTE_IP] [USER]

REMOTE_HOST="${1:-192.168.1.1}"
REMOTE_USER="${2:-root}"
BUNDLE_DIR="avp_bundle"
BUNDLE_TAR="avp_bundle.tar.gz"
REMOTE_DIR="/tmp/avp_bundle"

echo "AVP Bundle Deployment Tool"
echo "--------------------------"

# 1. Create Tarball
echo "Creating bundle tarball..."
tar -czf "${BUNDLE_TAR}" -C "." "${BUNDLE_DIR}"

# 2. Transfer to Device
echo "Transferring bundle to ${REMOTE_USER}@${REMOTE_HOST}..."
scp "${BUNDLE_TAR}" "${REMOTE_USER}@${REMOTE_HOST}:/tmp/"

# 3. Remote Install
echo "Executing remote installation..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" << EOF
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
