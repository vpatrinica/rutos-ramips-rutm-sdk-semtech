# AGENTS.md — Teltonika RUTM OpenWrt Firmware

This is a Teltonika RUTM-series router firmware based on OpenWrt. It targets
MediaTek MT7621 (MIPS `mipsel_24kc`) and produces complete firmware images
with Linux kernel 6.6.x, U-Boot, SquashFS rootfs, and ~300 VUCI web UI packages.

## Build Commands

```sh
# Docker build (recommended)
./scripts/dockerbuild ./scripts/feeds update -a
./scripts/dockerbuild make -j$(nproc)

# Host build
./scripts/feeds update -a
make -j$(nproc)

# Verbose build (for debugging failures)
make -j1 V=s
```

### Configuration

```sh
make menuconfig          # Interactive config editor
make defconfig           # Apply defaults
make kernel_menuconfig   # Kernel-specific config
```

### Single Package Build

```sh
make package/<name>/compile V=s          # Build one package
make package/<name>/clean                # Clean one package
make package/<name>/compile -j$(nproc)   # Parallel single-package build
```

Package lifecycle stages: `download` → `prepare` → `configure` → `compile` → `install`.

### Clean

```sh
make clean       # Remove build_dir, staging_dir, bin, logs
make dirclean    # clean + host staging, toolchain, tmp
make distclean   # Full reset (removes .config, feeds, dl, etc.)
```

### Firmware Output

- Firmware images: `bin/targets/ramips/generic/tltFws/`
- Package .ipk files: `bin/packages/<arch>/`
- Package manager bundle: `make pm` → `bin/packages/<arch>/zipped_packages/`

## Test Commands

```sh
make itest TEST=<test_file>      # Run a specific integration test
make itest TEST=shell            # Interactive shell in emulator
make itest TEST=<test_file> DEBUG=1  # Debug mode (port 42069)
make vuci-test                   # Runs feeds/vuci/tests/run_integration.py
```

Requires `bin/targets/x86/**/tltFws/X86*_LIVE.iso` built first. Uses Docker
with QEMU/KVM via `scripts/docker-bootstrap`.

Per-package `test.sh` scripts exist for on-device validation: `test.sh <pkg> <ver>`.
For packages with a Ceedling `project.yml`: `ceedling test:all` / `ceedling gcov:all`.

## Lint / Static Analysis

```sh
# checkpatch.pl (OpenWrt-adapted, v0.32)
./scripts/checkpatch.pl --file <source_file.c>
git diff HEAD~1 | ./scripts/checkpatch.pl -

# cppcheck (build first, then run)
make tools/cppcheck/compile
staging_dir/host/bin/cppcheck --enable=all --suppress=missingIncludeSystem <src_dir>
```

checkpatch.pl enforces: 100-char max line length, 8-wide tab indentation,
K&R braces for control flow, Linux kernel function brace style, proper spacing.

## Code Style — C (Teltonika-authored code)

Follow Linux kernel style with OpenWrt adaptations. checkpatch.pl is the
authoritative checker.

### Indentation and Formatting

- **Tabs** for indentation, tab width 8
- Max line length: **100 characters**
- K&R brace style for control structures (opening brace on same line)
- Function opening brace on **its own line** (Linux kernel convention)
- C99 `//` comments are allowed alongside `/* */`

### Naming Conventions

| Element       | Convention     | Example                          |
|---------------|----------------|----------------------------------|
| Functions     | `snake_case`   | `fsb_context_load`, `log_open`   |
| Variables     | `snake_case`   | `socket_connected`, `log_level`  |
| Macros        | `UPPER_CASE`   | `FSB_CONFIG_MAGIC`, `MAX_LOG_MSG`|
| Struct tags   | `name_s`       | `struct fsb_config_s`            |
| Typedefs      | `snake_case`   | `typedef struct foo_s { } foo;`  |
| Enum members  | `UPPER_CASE`   | `FSB_PARTITION_PRIMARY`, `L_DEBUG`|

### Header Guards

Use `#ifndef`/`#define` (not `#pragma once`):

```c
#ifndef __TLT_FSB_H__
#define __TLT_FSB_H__
/* ... */
#endif
```

### Error Handling

- Use `goto cleanup` pattern for resource cleanup in complex functions
- Return negative errno values: `-ENOMEM`, `-EINVAL`, `-EFAULT`
- Check return values immediately; early-return on error
- Use `static` for file-local functions

### License Header

```c
/* SPDX-License-Identifier: GPL-2.0-only */
```

## Code Style — Shell Scripts

- Shebang: `#!/bin/sh` (POSIX sh, not bash)
- Constants/globals: `UPPER_CASE` (`PACK_DIR`, `ROOT_DIR`)
- Local variables: `lower_case` with `local` keyword
- Functions: `snake_case` (`generate_random_str`, `get_mnf_info`)
- Quote variables: `"$var"` (double quotes)
- Source libs with `.` (dot): `. /lib/functions.sh`
- OpenWrt config: `config_load`, `config_get`, `config_foreach`
- JSON: use `jshn.sh` (`json_init`, `json_load`, `json_get_var`)

## Code Style — Lua

- Indentation: tabs or 4 spaces (be consistent within a file)
- Variables/functions: `snake_case`
- Constants: `UPPER_CASE`
- Imports: `local mod = require "module"`
- Error handling: `if not ok then ... return end`
- VUCI API backends live at `package/feeds/vuci/*/files/usr/lib/lua/api/`

## Code Style — OpenWrt Package Makefiles

Follow the OpenWrt package template (see `ipk-example/` for a full example).
Structure: `include rules.mk` → `PKG_NAME/VERSION/RELEASE` → `include package.mk`
→ `define Package/...` → `define Build/Compile` → `define Package/.../install`
→ `$(eval $(call BuildPackage,...))`. Copyright: `# Copyright (C) YEAR Teltonika`.

Install macros: `$(INSTALL_DIR)` (mkdir), `$(INSTALL_BIN)` (0755),
`$(INSTALL_DATA)` (0644), `$(INSTALL_CONF)` (0600).

`PKG_NAME`: lowercase with hyphens. Deps: `+pkg` required, `@CONFIG` conditional.

## Feeds & Project Layout

```sh
./scripts/feeds update -a && ./scripts/feeds install -a   # Update all feeds
./scripts/feeds search <name>                              # Find a package
```

```
package/teltonika/   — Teltonika-authored packages (C daemons, libs, utils)
package/feeds/vuci/  — VUCI web UI packages (Vue 3 + TypeScript, Lua API)
target/linux/        — Kernel config, patches, device trees
scripts/             — Build helpers, dockerbuild, checkpatch, deploy
include/             — Makefile infrastructure (package.mk, image.mk, cmake.mk)
ipk-example/         — Template for creating new packages
```

## LoRaWAN BasicStation — Subsystem Guide

LoRaWAN BasicStation is the gateway software that connects Semtech SX1302/SX1303
USB concentrator hardware to a LoRaWAN Network Server (LNS) or CUPS endpoint
(e.g. The Things Network). It consists of 5 packages deployed as a bundle.

### Architecture

```
                 VUCI Web Interface
              /                      \
vuci-app-basicstation-ui    vuci-app-basicstation-api
     (Vue 3 SPA)              (Lua REST API)
                                    |
                           UCI config: /etc/config/basicstation
                                    |
                         init.d/basicstation (procd)
                           builds station.conf JSON
                                    |
                            /usr/bin/station
                         (lora-basicstation binary)
                           /                \
                    libmbedtls           libloragw (sx1302_hal)
                   (TLS to LNS)       (SX1302/SX1303 HAL)
                        |                    |
                   LNS/CUPS Server     USB concentrator
                  (e.g. TTN)           (/dev/ttyACM0)
```

### GPS Data Flow

The station binary needs GPS position data. This uses a bridge service:

```
gpsd daemon --writes NMEA--> /mnt/gps.nmea (flat file, appended)
                                  |
                            tail -F (gps_bridge "bridge" instance)
                                  |
                                  v
                            /mnt/gps.fifo (named FIFO)
                                  |
                                  v
                         station binary (reads FIFO, parses $xxGGA)
```

The `gps_bridge` init script also runs a "janitor" instance that trims
`/mnt/gps.nmea` when it exceeds 100 KB to prevent unbounded growth on `/mnt`.

### Packages (install order matters)

| # | Package | Path | Purpose |
|---|---------|------|---------|
| 1 | `libmbedtls21` | `package/libs/mbedtls/` | TLS library v3.6.5 for LNS/CUPS connections |
| 2 | `sx1302_hal-utils` | `package/libs/sx1302_hal/` | SX1302/SX1303 HAL v2.1.0 + device utils |
| 3 | `lora-basicstation` | `package/feeds/packages/lora-basicstation/` | Gateway daemon v1.0.0 (Teltonika fork, bundled source, CMake) |
| 4 | `vuci-app-basicstation-api` | `package/feeds/vuci/vuci-app-basicstation-api/` | Lua REST API backend (BasicService framework) |
| 5 | `vuci-app-basicstation-ui` | `package/feeds/vuci/vuci-app-basicstation-ui/` | Vue 3 SPA frontend (tabs: General, Advanced, Log) |

There is also an older upstream package `basicstation` (v2.0.6) at
`package/feeds/packages/basicstation/` — this is the predecessor that downloads
source from GitHub. Use `lora-basicstation` instead.

### Key Files

**Daemon and init:**

- `lora-basicstation/src/` — Full C source (TLS, radio, CUPS, TC, JSON, logging)
- `lora-basicstation/files/etc/init.d/basicstation` — procd init (START=85), builds `station.conf` JSON via `jshn.sh`
- `lora-basicstation/files/etc/init.d/gps_bridge` — procd init (START=95), GPS NMEA bridge and janitor
- `lora-basicstation/files/etc/config/basicstation` — UCI config (auth, sx130x, rfconf, rssitcomp, txlut, station)
- `lora-basicstation/files/etc/config/gps` — UCI config for Teltonika gpsd, enables NMEA collecting to `/mnt/gps.nmea`
- `lora-basicstation/patches/001-build-with-mbedtls-3.x.patch` — Adapts upstream TLS code for mbedtls 3.x API

**API backend:**

- `vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua` — Main handler (extends `BasicService`)
- `vuci-app-basicstation-api/files/usr/share/vuci/path.d/vuci-app-basicstation.json` — URL routing

**API routing rules** (defined in `path.d/vuci-app-basicstation.json`):

- `/api/basicstation` → `GET_TYPE_` (root)
- `/api/basicstation/{service_group}` → `GET_TYPE_{service_group}()`
- `/api/basicstation/{service_group}/{sid}` → `GET_TYPE_{service_group}(sid)`

Important: The URL path segments map directly to `GET_TYPE_*` / `POST_TYPE_*`
Lua method names. For example, `/api/basicstation/rfconf` calls
`GET_TYPE_rfconf()`. Do NOT nest them as `/api/basicstation/config/rfconf` —
that would call `GET_TYPE_config(sid="rfconf")` which is a different method.

**Frontend:**

- `vuci-app-basicstation-ui/src/src/views/services/Basicstation.vue` — Single Vue component with 3 tabs
- Build: `npm install && npm run compile` (uses Vite, outputs gzipped JS/CSS)

### UCI Config Structure (`/etc/config/basicstation`)

```
station    — Station identity (idGenIf, stationid, logLevel, log_size, log_rotate)
auth       — LNS/CUPS auth (cred, mode, addr, port, token, trust/key/crt paths)
sx130x     — Concentrator HW (comif, devpath, pps, public, clksrc, radio0, radio1)
rfconf     — RF config sections (type, freq, txEnable, antennaGain, rssiOffset, useRssiTcomp)
rssitcomp  — RSSI temp compensation (coeff_a through coeff_e)
txlut      — TX gain lookup table (rfPower, paGain, pwrIdx, usedBy)
```

### Build and Deploy

```sh
# Build individual packages
make package/vuci-app-basicstation-api/clean && make package/vuci-app-basicstation-api/compile V=s
make package/vuci-app-basicstation-ui/clean  && make package/vuci-app-basicstation-ui/compile V=s
make package/lora-basicstation/clean         && make package/lora-basicstation/compile V=s

# Deploy all LoRaWAN packages to device (builds bundle, scps, installs)
# Defaults from environment (.env)
```

The deploy script (`host_deploy.sh`) searches `bin/packages/` for IPKs matching
`basicstation|lora|mbedtls|sx1302`, bundles them into `avp_bundle/`, generates
an `install.sh`, tars everything, SCPs to device `/tmp/`, and runs the install.

### Pre-built Bundle (`avp_bundle/`)

Contains pre-built IPKs for quick deployment without rebuilding:

- `libmbedtls21_3.6.5-1_mipsel_24kc.ipk`
- `sx1302_hal-utils_2.1.0-1_mipsel_24kc.ipk`
- `lora-basicstation_1.0.0-3_mipsel_24kc.ipk`
- `vuci-app-basicstation-api_4_mipsel_24kc.ipk`
- `vuci-app-basicstation-ui_4_mipsel_24kc.ipk`
- `install.sh` — Removes then reinstalls in dependency order

### VUCI Upload Framework (Critical Reference)

The VUCI upload framework has several non-obvious behaviors. Understanding
these is essential for implementing file uploads in any VUCI service.

**Upload pipeline execution order:**

```
UPLOAD_validate_path() → UPLOAD_init() returns {handle_request=fn} →
formdata_parser parses multipart stdin → handle_request(upload_request) →
framework moves temp files to file.location → UPLOAD_after_upload_hook()
```

**Key constraints:**

1. `formdata_parser.lua` ONLY recognizes form fields named `"file"` as file
   uploads. Any other field name goes into `upload_request.parameters`, NOT
   `upload_request.files`. This is hardcoded in the compiled bytecode parser.

2. The `tlt-upload` Vue component sends:
   - `FormData.append("file", this.file)` — always hardcoded field name `"file"`
   - `FormData.append("option", this.name)` — the `name` prop value as a text field
   - There is NO `data`, `extra-data`, or `headers` prop on `tlt-upload`

3. `file.content_disposition` is nil in `handle_request` — the framework strips
   it. You CANNOT use `file.content_disposition.name` to identify upload type.

4. To determine the upload type/purpose, read `upload_request.parameters.option`
   (set by `tlt-upload`'s `name` prop), NOT `file.fieldname` (doesn't exist).

5. `service_groups_enum` validation: If your service only defines `config` and
   `actions` groups but needs `/upload` endpoint, either add `"upload"` to the
   enum or set `BasicStation.disable_upload_service_group_check = true`.

6. `UPLOAD_validate_path()` must return `true` or the upload is rejected before
   any handler runs.

**Permission requirements for uploads:**

- uhttpd runs as unprivileged `uhttpd` user (not root)
- Target directories (e.g. `/etc/basicstation/`) must be writable by uhttpd
- UCI config files must be writable by uhttpd for `uci.cursor():commit()` to work
- Use `os.execute("chmod ...")` instead of `nixio.fs.chmod()` (which also runs as uhttpd)
- In package Makefiles: use `install -m0666` for UCI configs that the web UI writes to
- Pre-create upload target directories in the Makefile with `$(INSTALL_DIR)`

**Example: determining cert type in handle_request:**

```lua
function BasicStation:handle_request(upload_request)
    local cert_type = "trust"  -- default
    if upload_request.parameters then
        cert_type = upload_request.parameters.option    -- from tlt-upload name prop
                 or upload_request.parameters.cert_type  -- for curl testing
                 or cert_type
    end
    -- cert_type is now "trust", "key", or "crt"
end
```

**Testing uploads with curl (simulating tlt-upload):**

```sh
curl -k -F "file=@/tmp/test.pem" -F "option=key" \
  https://127.0.0.1/api/basicstation/upload
```

### Known Issues and Past Fixes

**Log tab showing empty (FIXED):** The log file `/tmp/basicstation/log` was
created by the station binary with permissions `640 root:root` (in `sys_log.c`
line 157). The Lua API's `fs.access()` check returned false for the uhttpd
user, causing an early return with empty string. Even `io.open()` and
`io.popen("cat ...")` fail because they inherit uhttpd's uid. Fixed in 3
places: (a) `sys_log.c:157` changed to mode `0644` (added `S_IROTH`),
(b) init script pre-creates log with `chmod 0644` before starting station,
(c) Lua API removed `fs.access()` guard and uses simple `io.open()`.

**RF/RSSI dropdowns not populating (FIXED):** The Vue component was calling
`/api/basicstation/config/rfconf` (wrong — routes to `GET_TYPE_config(sid="rfconf")`
which returns unfiltered data). Fixed to `/api/basicstation/rfconf` (routes to
`GET_TYPE_rfconf()` which returns only rfconf-typed sections). Same fix applied
for `/api/basicstation/rssitcomp`.

**Station ID and Token not saving (FIXED):** The Vue component was using the
default component name as the API base, resulting in `PUT /api/basicstation/config/*`
which the custom Lua API did not implement (501 Not Implemented). Fixed by adding
`api="/api/uci"` to `vuci-form` to use the standard VUCI UCI API.

**Station ID override disabled (FIXED):** The `stationid` field was marked as
`readonly` and `disabled`. Removed these attributes to allow manual overrides
when the auto-generated ID (from MAC) is not desired.

**File upload saving all certs as tc.trust (FIXED):** Multiple root causes:
(a) `file.fieldname` doesn't exist in the upload framework, (b)
`file.content_disposition` is stripped by framework, (c) `service_groups_enum`
didn't include `upload` causing path validation failure, (d) `/etc/basicstation/`
directory didn't exist and couldn't be created by uhttpd, (e) UCI config not
writable by uhttpd so `uci.cursor():commit()` silently failed. Fixed by reading
cert type from `parameters.option`, disabling service group check, overriding
`UPLOAD_validate_path()`, using `os.execute("chmod")`, and fixing Makefile
permissions.

**rules="float" crashes Vue component (FIXED):** VUCI's validation compiler
does NOT support `float` as a rule token. Using `rules="float"` on any
`vuci-form-item-input` throws `Error: Unhandled token float` in `Object.compile`,
which crashes the `convertedRules` computed property. Because Vue computed
properties propagate errors, this crashes the ENTIRE component — not just the
input field, but all tabs (General, Advanced, Log). Valid rule tokens include:
`uinteger`, `integer`, `range(min,max)`. For decimal/float fields, omit the
`rules` prop entirely — the station binary validates values at startup. Fixed
by removing `rules="float"` from rssiOffset and all 5 rssitcomp coefficient
inputs.

**gps_bridge truncation race (FIXED):** The janitor used `: > $LOG_FILE` to
truncate, which caused `tail -f` to lose its position and miss data. Fixed by:
(a) switching to `tail -F` (follows by name, handles truncation), (b) trimming
with `tail -n 500` instead of full truncation, (c) guarding against missing file.

**gps_bridge not installed (FIXED):** The `gps_bridge` init script and `gps`
UCI config existed in `files/` but were not listed in the package Makefile
`install` section. Added to `Package/lora-basicstation/install`.

**Upload framework silently failing to move files (FIXED):** The upload
framework uses `nixio.fs.move()` to move the temp file (on `/tmp` tmpfs) to
the target path (on `/etc` overlayfs). These are different mount points, so
`rename()` returns `EXDEV` and nixio falls back to copy+delete. However, when
the target file already exists and is owned by `root`, the copy fails with
`EACCES` (errno 13) because uhttpd cannot overwrite a root-owned file — even
in a world-writable directory on overlayfs. The framework does not check the
return value, so `handle_request` returns success, `UPLOAD_after_upload_hook`
runs (UCI gets updated), but the file on disk is unchanged. Fixed by calling
`fs.remove(cert_info.path)` in `handle_request` before setting `file.location`,
so the framework's move creates a fresh file (which uhttpd can do in a
world-writable directory) instead of trying to overwrite.

**Key insight — nixio.fs.move() cross-device quirk:** When moving across mount
points as a non-root user, `nixio.fs.move()` returns `nil, 1` even on success
(the file IS moved despite the error return code). But when the target exists
and is root-owned, it returns `nil, 13` (EACCES) and the move genuinely fails.
Always remove the target first when running as uhttpd.

### Python and mbedTLS

There is **no** `python-mbedtls` or `python3-mbedtls` package in this codebase.
The `mbedtls` library (`package/libs/mbedtls/`, v3.6.5) is a pure C library
used by BasicStation for TLS. The only Python-related reference is
`micropython-mbedtls` in the MicroPython package (unrelated to LoRaWAN).

The `deploy_packages.sh` script has a commented-out list of Python packages
(pyopenssl, cryptography, etc.) that were once considered for deployment but
are not part of the current LoRaWAN bundle.

### Device Access

- Access details are managed via the `.env` file.
- SSH: `ssh root@[DEVICE_IP]`
- VUCI web UI: `https://[DEVICE_IP]` (self-signed cert)
- BasicStation page: Services > LoRaWAN BasicStation
