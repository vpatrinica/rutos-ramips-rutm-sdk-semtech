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
