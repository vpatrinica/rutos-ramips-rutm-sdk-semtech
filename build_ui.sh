#!/bin/bash

# AVP Build Script
# Usage: ./build_ui.sh [vuci|station|all]
#
#   vuci     – Build VUCI packages (basicstation-ui + basicstation-api)
#   station  – Build VUCI + lora-basicstation
#   all      – Build station + python packages
#
# Default: vuci

set -e

MODE="${1:-vuci}"

UI_SRC_DIR="package/feeds/vuci/vuci-app-basicstation-ui/src"
BUILD_FILE="${UI_SRC_DIR}/build.json"
BUILD_NUM_FILE="${UI_SRC_DIR}/.build_number"

# ---------- Build number bookkeeping ----------
[ -f "${BUILD_NUM_FILE}" ] || echo "0" > "${BUILD_NUM_FILE}"
BUILD_NUM=$(( $(cat "${BUILD_NUM_FILE}") + 1 ))
echo "${BUILD_NUM}" > "${BUILD_NUM_FILE}"
BUILD_TIME=$(date +'%Y-%m-%d %H:%M')
cat > "${BUILD_FILE}" <<EOF
{"buildVersion": "${BUILD_TIME}", "buildNumber": ${BUILD_NUM}}
EOF

# ---------- Helper ----------
build_pkg() {
    local pkg="$1"
    echo "── clean  ${pkg}"
    ./scripts/dockerbuild make "${pkg}/clean" V=sc
    echo "── build  ${pkg}"
    ./scripts/dockerbuild make "${pkg}/compile" V=sc
}

# ---------- VUCI (always built) ----------
echo "═══════════════════════════════════════"
echo "  Build mode : ${MODE}"
echo "  Build #    : ${BUILD_NUM}"
echo "  Timestamp  : ${BUILD_TIME}"
echo "═══════════════════════════════════════"

echo ""
echo "▸ Building VUCI packages..."
build_pkg package/feeds/vuci/vuci-app-basicstation-ui
build_pkg package/feeds/vuci/vuci-app-basicstation-api

# ---------- Station (station | all) ----------
if [ "${MODE}" = "station" ] || [ "${MODE}" = "all" ]; then
    echo ""
    echo "▸ Building lora-basicstation..."
    build_pkg package/feeds/packages/lora-basicstation
fi

# ---------- Python packages (all) ----------
if [ "${MODE}" = "all" ]; then
    echo ""
    echo "▸ Building Python packages..."

    # Core python3 runtime
    build_pkg package/lang/python/python3

    # Third-party python packages used by the project
    PYTHON_PKGS=(
        python-pyserial
        python-pymodbus
        python-paramiko
        python-six
        python-uci
        python-requests
        python-urllib3
        python-certifi
        python-chardet
        python-idna
    )

    for pkg in "${PYTHON_PKGS[@]}"; do
        pkgpath="package/lang/python/${pkg}"
        if [ -d "${pkgpath}" ]; then
            build_pkg "${pkgpath}"
        else
            echo "   ⚠ ${pkgpath} not found, skipping"
        fi
    done
fi

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Build complete! (mode: ${MODE})"
echo "═══════════════════════════════════════"
