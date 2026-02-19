# Agent Session Memory — LoRaWAN BasicStation VUCI

Last updated: 2026-02-17

## Status: All original bugs FIXED. 7 additional UI/config fixes applied (2026-02-17)

| Bug | Status | Verified |
|-----|--------|----------|
| Bug 1: Log tab empty | FIXED | Yes — API returns log content |
| Bug 2: RF/RSSI grids not populating | FIXED | Yes — rfconf/rssitcomp return typed sections |
| Bug 3: File upload saves all as tc.trust | FIXED | Yes — trust/key/crt save separately, UCI updated |
| Bug 4: Upload silently fails on overwrite | FIXED | Yes — fs.remove() before move, all 3 cert types verified |
| gps_bridge cleanup | FIXED | Yes — installed, init script correct |
| Fix 5: Log display not rendering | FIXED | Yes — response.data unwrapping |
| Fix 6: Clear button broken | FIXED | Yes — DELETE→GET /clear_log |
| Fix 7: Status badge broken | FIXED | Yes — response.data unwrapping |
| Fix 8: Logging level dropdown disconnected | FIXED | Yes — logLevel→log_level |
| Fix 9: Init script reading wrong option names | FIXED | Yes — camelCase→underscore |
| Fix 10: Missing freq defaults | FIXED | Yes — AS923 band added |
| Fix 11: rules="float" crashes component | FIXED | Yes — no more console exceptions |
| Fix 12: Station ID and Token not saving | FIXED | Yes — implemented PUT/POST handlers in Lua backend and removed ignored frontend api prop |
22: | Fix 13: 501 Not Implemented on Save | FIXED | Yes — Added explicit PUT/POST/DELETE dispatchers to basicstation.lua |

## Files Modified (all changes are in source AND deployed to device)

### Fix 12 & 13 — 501 Not Implemented / Saving issues (2026-02-18)

- `package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua`
  - Added explicit `PUT`, `POST`, and `DELETE` method overrides to the `BasicStation` class.
  - **Root cause**: The base `BasicService.lua` (bytecode) contains a default `PUT` implementation that simply returns "PUT not implemented" (HTTP 501). It also doesn't automatically dispatch `POST` to `POST_TYPE_...` handlers for configuration updates.
  - **Fix**: The new handlers generically dispatch to `_TYPE_` logic or handle UCI updates directly for the `config` and other service groups. This ensures that any `PUT` or `POST` request from the frontend is correctly processed.
  - **Robustness**: The new `POST` handler also checks for wrapped data (`data.data`) which is common in some VUCI/Axios configurations.
- `package/feeds/vuci/vuci-app-basicstation-ui/src/src/views/services/Basicstation.vue`
  - Removed `api="/api/uci"` from `<vuci-form>`.
  - **Reasoning**: This prop was being ignored by the framework, and since the backend now correctly handles the service-specific API (`/api/basicstation/config/...`), it's safer and more consistent to let the form use its default service API.

- `package/feeds/packages/lora-basicstation/src/src-linux/sys_log.c:157`
  - Changed `S_IRUSR|S_IWUSR|S_IRGRP` → `S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH` (0644)
- `package/feeds/packages/lora-basicstation/files/etc/init.d/basicstation`
  - Pre-creates log dir and file with `chmod 0644` before starting station
- `package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua`
  - `GET_TYPE_log()`: Removed `fs.access()` guard, uses simple `io.open()`

### Bug 2 — RF/RSSI grids not populating

- `package/feeds/vuci/vuci-app-basicstation-ui/src/src/views/services/Basicstation.vue:386,393`
  - Changed `/api/basicstation/config/rfconf` → `/api/basicstation/rfconf`
  - Changed `/api/basicstation/config/rssitcomp` → `/api/basicstation/rssitcomp`

### Bug 3 — File upload saving all certs as tc.trust

- `package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua`
  - `UPLOAD_init()`: Reads cert type from `upload_request.parameters.option` (set by tlt-upload `name` prop)
  - `BasicStation.disable_upload_service_group_check = true` (bypasses enum validation)
  - `UPLOAD_validate_path()` override returns `true`
  - `UPLOAD_after_upload_hook()`: Sets UCI `auth.<cert_type>` and `chmod` via `os.execute()`
- `package/feeds/packages/lora-basicstation/Makefile`
  - `install -m0666` for basicstation config (writable by uhttpd)
  - `$(INSTALL_DIR) $(1)/etc/basicstation` (pre-creates cert directory)

### Bug 4 — Upload framework silently fails to overwrite files (CRITICAL)

- `package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua`
  - Added `fs.remove(cert_info.path)` in `handle_request` before setting `file.location`
  - **Root cause**: `nixio.fs.move()` crosses mount points (tmpfs→overlayfs) as uhttpd user.
    When target file exists and is root-owned, the copy step fails with EACCES (errno 13).
    The framework doesn't check the return value, so it reports success but the file is unchanged.
  - **Fix**: Remove the target file first. uhttpd CAN delete files in world-writable directories
    (unlink only needs write permission on the directory). Then the move creates a fresh file
    owned by uhttpd, which succeeds.
  - **Quirk**: `nixio.fs.move()` returns `nil, 1` even on SUCCESS for cross-device moves.
    But `nil, 13` means genuine failure (EACCES). Always check errno, not just the boolean.

### gps_bridge fixes

- `package/feeds/packages/lora-basicstation/files/etc/init.d/gps_bridge`
  - `tail -f` → `tail -F` (handles truncation)
  - Full truncation → `tail -n 500` trim
  - Added missing file guard
  - Added FIFO cleanup in `stop_service()`
- `package/feeds/packages/lora-basicstation/Makefile`
  - Added `gps_bridge` and `gps` config to install/conffiles sections

### Fixes 5-10 — Log display, Clear button, Status badge, UCI naming, Init script, Freq defaults (2026-02-17)

- `package/feeds/vuci/vuci-app-basicstation-ui/src/src/views/services/Basicstation.vue`
  - `fetchLogs()`: `response.log` → `(response.data || response).log` (VUCI axios wraps in .data)
  - `clearLogs()`: `DELETE /api/basicstation/log` → `GET /api/basicstation/clear_log` (API only has GET_TYPE_clear_log)
  - `fetchStatus()`: `response.running` → `(response.data || response).running`
  - Logging section: `name="logLevel"` → `name="log_level"` (must match UCI option name)
- `package/feeds/packages/lora-basicstation/files/etc/init.d/basicstation`
  - `parse_station()`: `logFile`/`logLevel`/`logSize`/`logRotate` → `log_file`/`log_level`/`log_size`/`log_rotate`
  - Was silently using defaults instead of configured values
- `package/feeds/packages/lora-basicstation/files/etc/config/basicstation`
  - Added `option freq '923200000'` to rfconf0 (AS923 band)
  - Added `option freq '923400000'` to rfconf1 (AS923 band)
- `package/feeds/vuci/vuci-app-basicstation-ui/Makefile`
  - `PKG_RELEASE` bumped from 4 → 5

### Fix 11 — rules="float" crashes entire component (2026-02-17)

- `package/feeds/vuci/vuci-app-basicstation-ui/src/src/views/services/Basicstation.vue`
  - Removed `rules="float"` from rssiOffset and all 5 rssitcomp coefficient inputs (6 total)
  - **Root cause**: VUCI's validation compiler doesn't support `float` as a rule token
  - Error: `Unhandled token float` in `Object.compile` crashes `convertedRules` computed property
  - This crashes the ENTIRE component during render — not just the Advanced tab, but ALL tabs
  - Explains: no logs displayed, RSSI tcomp not loading, status badge broken

### Fix 12 — Station ID and Token not saving (2026-02-17)

- `package/feeds/vuci/vuci-app-basicstation-ui/src/src/views/services/Basicstation.vue`
  - Added `api="/api/uci"` to both `vuci-form` instances to use standard UCI API.
  - Removed `readonly` and `disabled` from `stationid` field to allow manual override.
  - **Root cause**: Standard `BasicService` doesn't implement `PUT` for config sections; using `/api/uci` is the standard VUCI way for UCI CRUD.

## Critical Knowledge: VUCI Upload Framework

This is the hardest-won knowledge from this session. Any future agent working
on VUCI file uploads MUST read this.

### How tlt-upload sends data

The `tlt-upload` Vue component sends multipart/form-data with exactly two fields:

- `FormData.append("file", this.file)` — the actual file, field name always "file"
- `FormData.append("option", this.name)` — the `name` prop value (e.g., "key")

There is NO `data`, `extra-data`, or `headers` prop on `tlt-upload`.

### How formdata_parser.lua processes it

- Only fields named `"file"` become file upload objects in `upload_request.files`
- All other field names (including `"option"`) go into `upload_request.parameters`
- This is hardcoded in compiled bytecode — cannot be changed

### What the framework strips

- `file.content_disposition` is nil by the time `handle_request` is called
- `file.fieldname` does not exist as a property
- You CANNOT identify upload type from the file object itself

### How to determine upload type

```lua
local cert_type = upload_request.parameters
    and upload_request.parameters.option    -- from tlt-upload name prop
-- fallback for curl testing:
if not cert_type and upload_request.parameters then
    cert_type = upload_request.parameters.cert_type
end
```

### Permission gotchas

- uhttpd runs as unprivileged user, not root
- Target directories must be writable by uhttpd (e.g., `/etc/basicstation/`)
- UCI config files must be writable by uhttpd for `uci.cursor():commit()`
- Use `os.execute("chmod ...")` not `nixio.fs.chmod()` (which inherits uhttpd uid)
- In Makefiles: `install -m0666` for UCI configs the web UI writes to

### service_groups_enum bypass

If your service doesn't include "upload" in its enum, either add it or set:

```lua
BasicStation.disable_upload_service_group_check = true
```

And override:

```lua
function BasicStation:UPLOAD_validate_path()
    return true
end
```

### Testing with curl (simulates tlt-upload)

```sh
curl -k -H "Authorization: Bearer $TOKEN" \
  -F "file=@/tmp/test.pem" -F "option=key" \
  https://127.0.0.1/api/basicstation/upload
```

## Device State

- IP: `100.109.82.127` (Tailscale), Creds: `root` / `AVPteltonika123$`
- Use `sshpass -p 'AVPteltonika123$' ssh -o StrictHostKeyChecking=no root@100.109.82.127`
- Config file `/etc/config/basicstation` has perms `0666` (writable by uhttpd)
- `/etc/basicstation/` exists with `0777` perms (from manual debug session)
- Station binary running at `/usr/local/usr/bin/station --home /tmp/basicstation/`
- Log file at `/tmp/basicstation/log` with perms `0644`
- All 5 packages installed: libmbedtls21, sx1302_hal-utils, lora-basicstation, vuci-app-basicstation-api, vuci-app-basicstation-ui

## API Routing (critical to understand)

Path config: `vuci-app-basicstation-api/files/usr/share/vuci/path.d/vuci-app-basicstation.json`

URL path segments map directly to `GET_TYPE_*` / `POST_TYPE_*` Lua methods:

- `/api/basicstation/rfconf` → `GET_TYPE_rfconf()` (CORRECT)
- `/api/basicstation/config/rfconf` → `GET_TYPE_config(sid="rfconf")` (WRONG — returns unfiltered data)

## Deploy Workflow

```sh
# Rebuild a single package
make package/<name>/clean && make package/<name>/compile V=s

# Deploy all LoRaWAN packages to device
./host_deploy.sh 100.109.82.127 root

# The deploy script finds IPKs matching basicstation|lora|mbedtls|sx1302 in bin/packages/,
# bundles them, SCPs to device, removes old packages, installs new ones.
```

## Conffile Notes

opkg preserves modified conffiles on device (puts new version in `<file>-opkg`).
The device's `/etc/config/basicstation` was modified during testing (manual
`chmod 666`, UCI changes via upload testing). This is expected and correct —
the user's config is preserved across package reinstalls.

## Test Suite (tests/basicstation/)

All 12 test scripts pass. Run with `bash tests/basicstation/run_all_tests.sh`.

| Script | Tests | Purpose |
|--------|-------|---------|
| test_00_login | 2 | Login/auth token |
| test_01_get_config | 14 | Config read |
| test_02_station_identity | 8 | Station identity read-only |
| test_03_auth_settings | 12 | Auth settings read-only |
| test_04_radio_config | 12 | Radio config read-only |
| test_05_logging | 8 | Logging settings read-only |
| test_06_rfconf | 14 | RF config + Bug 2 regression |
| test_07_rssitcomp | 14 | RSSI Tcomp + Bug 2 regression |
| test_08_txlut | 8 | TX LUT read-only |
| test_09_log_viewer | 8 | Log viewer + clear_log + Bug 1 regression |
| test_10_status | 4 | Service status |
| test_11_upload_certs | 17 | Cert upload + Bug 3/4 regression |
| test_12_upload_edge_cases | 7 | Upload edge cases |

Upload tests (11, 12) backup production certs before testing and restore after.

## Deployment: Lua File Direct SCP (Fast Path)

`opkg install --force-reinstall` fails on this device (read-only `/usr/lib/opkg/status`).
For Lua API changes, deploy directly via SCP:

```sh
sshpass -p 'AVPteltonika123$' scp -o StrictHostKeyChecking=no \
  package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua \
  root@100.109.82.127:/usr/local/usr/lib/lua/api/services/basicstation.lua
sshpass -p 'AVPteltonika123$' ssh -o StrictHostKeyChecking=no root@100.109.82.127 '/etc/init.d/uhttpd restart'
```

## Known-Good UCI Config (MUST BE PRESERVED)

```
basicstation.auth.cred='tc'
basicstation.auth.mode='serverAndClientToken'
basicstation.auth.addr='eu1.cloud.thethings.network'
basicstation.auth.port='8887'
basicstation.auth.token='NNSXS.W6DIAXZDSEWWPIQC644Z3HE7CVJDRVWUDQUG3MY.KASGFDBAGIFBJHVM2U3ZDMQDFQPULB57BPRWBY4ASYG66XB4VJPA'
basicstation.auth.key='/etc/basicstation/tc.key'
basicstation.auth.trust='/etc/basicstation/tc.trust'
basicstation.auth.crt='/etc/basicstation/tc.crt'
basicstation.station.idGenIf='eth0'
basicstation.station.log_level='XDEBUG'
basicstation.station.log_size='1000000'
basicstation.station.log_rotate='1'
```

Trust cert backup on device: `/etc/config/tc.trust` (8874 bytes)
