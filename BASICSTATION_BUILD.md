# BasicStation Build Guide

This document covers the build process for LoRaWAN BasicStation and its VUCI web interface packages.

## Packages Overview

| Package | Description |
|---------|-------------|
| `lora-basicstation` | LoRaWAN Basic Station daemon |
| `vuci-app-basicstation-api` | VUCI API backend for configuration |
| `vuci-app-basicstation-ui` | VUCI web UI frontend |
| `libmbedtls` | TLS library (dependency) |
| `sx1302_hal-utils` | SX1302 HAL utilities (dependency) |

## Prerequisites

Ensure toolchain is built first:

```bash
./scripts/dockerbuild make toolchain/install V=s
```

## Enable Packages in Config

```bash
# Add packages to .config
echo "CONFIG_PACKAGE_lora-basicstation=m" >> .config
echo "CONFIG_PACKAGE_vuci-app-basicstation-api=m" >> .config
echo "CONFIG_PACKAGE_vuci-app-basicstation-ui=m" >> .config
echo "CONFIG_PACKAGE_libmbedtls=m" >> .config
echo "CONFIG_PACKAGE_sx1302_hal-utils=m" >> .config

# Regenerate config
./scripts/dockerbuild make defconfig
```

## Build Dependencies

```bash
# Build mbedtls
./scripts/dockerbuild make package/libs/mbedtls/compile V=s

# Build sx1302_hal
./scripts/dockerbuild make package/libs/sx1302_hal/compile V=s
```

## Build Main Packages

```bash
# Build lora-basicstation
./scripts/dockerbuild make package/feeds/packages/lora-basicstation/compile V=s

# Build VUCI packages
./scripts/dockerbuild make package/feeds/vuci/vuci-app-basicstation-api/compile V=s
./scripts/dockerbuild make package/feeds/vuci/vuci-app-basicstation-ui/compile V=s
```

## Rebuild After Changes

```bash
# Clean and rebuild
./scripts/dockerbuild make package/feeds/packages/lora-basicstation/clean \
    package/feeds/packages/lora-basicstation/compile V=s
```

## Output IPK Files

```bash
# Find generated IPKs
find bin/packages -name "*.ipk" | xargs ls -lh | grep -E "basicstation|lora|mbedtls|sx1302"
```

Expected output locations:

- `bin/packages/mipsel_24kc/packages/lora-basicstation_*.ipk`
- `bin/packages/mipsel_24kc/vuci/vuci-app-basicstation-api_*.ipk`
- `bin/packages/mipsel_24kc/vuci/vuci-app-basicstation-ui_*.ipk`
- `bin/packages/mipsel_24kc/base/libmbedtls21_*.ipk`
- `bin/packages/mipsel_24kc/base/sx1302_hal-utils_*.ipk`

## Install on Device

```bash
# Copy to device and install in order
opkg install libmbedtls21_*.ipk
opkg install sx1302_hal-utils_*.ipk
opkg install lora-basicstation_*.ipk
opkg install vuci-app-basicstation-api_*.ipk
opkg install vuci-app-basicstation-ui_*.ipk
```

## Source Files

### lora-basicstation

- Source: `package/feeds/packages/lora-basicstation/src/`
- Config: `package/feeds/packages/lora-basicstation/files/etc/config/basicstation`
- Init script: `package/feeds/packages/lora-basicstation/files/etc/init.d/basicstation`

### VUCI API

- Lua API: `package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation_api.lua`
- ACL: `package/feeds/vuci/vuci-app-basicstation-api/files/usr/share/rpcd/acl.d/vuci-app-basicstation.json`
- Path: `package/feeds/vuci/vuci-app-basicstation-api/files/usr/share/vuci/path.d/vuci-app-basicstation.json`

### VUCI UI

- Vue component: `package/feeds/vuci/vuci-app-basicstation-ui/src/src/views/services/Basicstation.vue`
- Menu: `package/feeds/vuci/vuci-app-basicstation-ui/files/usr/share/vuci/menu.d/basicstation.json`

## Hotfixes Applied

1. **txpow check in s2e.c** - Changed `region == 0` to `txpow == 0` for router_config detection
2. **AS923-2/3/4 support** - Added to kwlist.txt

Configure steps:

Getting the EUI of the concentrator:

root@RUTM09:/usr/local/home/admin/avp-packages# chip_id -u -d /dev/ttyACM0
Opening USB communication interface
INFO: Configuring TTY
INFO: Flushing TTY
INFO: Setting TTY in blocking mode
INFO: Connect to MCU
INFO: Concentrator MCU version is V01.00.00
INFO: MCU status: sys_time:8932620 temperature:-0.0oC
Note: chip version is 0x10 (v1.0)
INFO: using legacy timestamp
ARB: dual demodulation disabled for all SF

INFO: concentrator EUI: 0x0016c001f118fa31

Closing USB communication interface
