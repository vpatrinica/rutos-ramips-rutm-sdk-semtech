#!/bin/bash

# AVP Host Deployment Script
# Usage: ./host_deploy.sh  [bundle_type]
#
# bundle_type defaults to "vuci" and controls which IPKs are packaged.

# Load .env if present
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    set -a
    . "${SCRIPT_DIR}/.env"
    set +a
fi

REMOTE_HOST="${DEVICE_IP:-192.168.1.1}"
REMOTE_USER="${DEVICE_USER:-root}"
BUNDLE_DIR="avp_bundle"
BUNDLE_TAR="avp_bundle.tar.gz"
REMOTE_DIR="/tmp/avp_bundle"

echo "AVP Bundle Deployment Tool"
echo "--------------------------"

# 1. Create Tarball
echo "Creating bundle tarball..."


# third argument controls which subset of packages to bundle. Default to "vuci" if not supplied.
# Usage additions: ./host_deploy.sh [REMOTE_IP] [USER] [bundle_type]
#
# - "vuci" (default) will only pick the two VUCI BasicStation web UI packages
# - "all" (or any other value) will grab every IPK matching our usual
#   patterns.  The patterns themselves can be fine‑tuned later.

BUNDLE_TYPE="${1:-vuci}"
echo "Bundle type: ${BUNDLE_TYPE}"

# decide which packages to copy based on the requested type
if [ "${BUNDLE_TYPE}" = "vuci" ]; then
    # only include the frontend/backend UI packages
    PATTERN="vuci-app-basicstation-(api|ui)"
else
    # everything related to BasicStation/LoRa/mbedtls/sx1302
    PATTERN="basicstation|lora|mbedtls|sx1302"
fi

mapfile -t PACKAGES < <(find bin/packages -name "*.ipk" | grep -E "${PATTERN}")

rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}"
for PKG in "${PACKAGES[@]}"; do
    cp "$PKG" "${BUNDLE_DIR}/"
done

#making the install script
cat > "${BUNDLE_DIR}/install.sh" << 'EOF'
#!/bin/sh

# BasicStation and LoRa components
# Only operate on the packages that are actually part of the bundle.

set -e

echo "Installing packages from bundle $(pwd)..."

# remove any installed copy of each package (ignores errors)
for pkgfile in *.ipk; do
    pname=$(basename "$pkgfile" | cut -d_ -f1)
    echo "Removing old $pname if present..."
    opkg remove --force-depends "$pname" 2>/dev/null || true
    # Forcefully delete left-over config files that OPKG refuses to overwrite on next install
    if [ "$pname" = "vuci-app-basicstation-ui" ]; then
        rm -f /usr/share/vuci/menu.d/basicstation.json
    fi
done

# install every IPK in the directory
for pkgfile in *.ipk; do
    echo "Installing $pkgfile..."
    opkg install --force-maintainer "$pkgfile"
done

echo "Reloading ACLs and restarting RPCD..."
ubus call session reload_acls
/etc/init.d/rpcd restart

 echo "Installation complete!"
EOF
chmod +x "${BUNDLE_DIR}/install.sh"


tar -czf "${BUNDLE_TAR}" -C "." "${BUNDLE_DIR}"

# 2. Transfer to Device
echo "Transferring bundle to ${REMOTE_USER}@${REMOTE_HOST}..."
export SSHPASS="${DEVICE_PASS}"
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
