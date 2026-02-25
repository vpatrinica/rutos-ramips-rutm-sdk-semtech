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


# Bundle type controls which IPKs are packaged.
#   vuci    – VUCI BasicStation web UI packages only
#   station – VUCI + lora-basicstation
#   all     – VUCI + lora-basicstation + python + deps

BUNDLE_TYPE="${1:-vuci}"
echo "Bundle type: ${BUNDLE_TYPE}"

# decide which packages to copy based on the requested type
if [ "${BUNDLE_TYPE}" = "vuci" ]; then
    PATTERN="vuci-app-basicstation-(api|ui)"
elif [ "${BUNDLE_TYPE}" = "station" ]; then
    PATTERN="vuci-app-basicstation-(api|ui)|lora-basicstation"
else
    # all — everything related to BasicStation/LoRa/mbedtls/sx1302/python
    PATTERN="basicstation|lora|mbedtls|sx1302|python"
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

# 4. Direct SCP of source files that may have changed since last ipk build
#echo "Syncing source Lua service file..."
#LUA_SRC="package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua"
#LUA_DST="/usr/local/usr/lib/lua/api/services/basicstation.lua"
#if [ -f "${LUA_SRC}" ]; then
#    sshpass -e scp -o StrictHostKeyChecking=no "${LUA_SRC}" "${REMOTE_USER}@${REMOTE_HOST}:${LUA_DST}"
#    echo "✅ Lua source synced"
#fi

if [ $? -eq 0 ]; then
    echo "--------------------------"
    echo "✅ Deployment and installation successful!"
else
    echo "--------------------------"
    echo "❌ Deployment failed!"
    exit 1
fi
