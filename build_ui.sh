#!/bin/bash

# Script to build vuci-app-basicstation-ui
# Automatically increments build number, updates build time, and runs dockerbuild

set -e

echo "Building vuci-app-basicstation-ui..."

UI_SRC_DIR="package/feeds/vuci/vuci-app-basicstation-ui/src"
BUILD_FILE="${UI_SRC_DIR}/build.json"
BUILD_NUM_FILE="${UI_SRC_DIR}/.build_number"

# Ensure .build_number exists
if [ ! -f "${BUILD_NUM_FILE}" ]; then
    echo "0" > "${BUILD_NUM_FILE}"
fi

# Increment build number
BUILD_NUM=$(cat "${BUILD_NUM_FILE}")
BUILD_NUM=$((BUILD_NUM + 1))
echo "${BUILD_NUM}" > "${BUILD_NUM_FILE}"

# Get current time
BUILD_TIME=$(date +'%Y-%m-%d %H:%M')

echo "Setting build version to '${BUILD_TIME}' and build number to ${BUILD_NUM}..."

# Write build.json
cat > "${BUILD_FILE}" << EOF
{"buildVersion": "${BUILD_TIME}", "buildNumber": ${BUILD_NUM}}
EOF

echo "Running dockerbuild clean..."
./scripts/dockerbuild make package/feeds/vuci/vuci-app-basicstation-ui/clean V=sc

echo "Running dockerbuild compile..."
./scripts/dockerbuild make package/feeds/vuci/vuci-app-basicstation-ui/compile V=sc

echo "Build complete!"
