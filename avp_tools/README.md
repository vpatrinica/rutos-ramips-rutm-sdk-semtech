# AVP LoRaWAN BasicStation Utility Tools

This directory contains a suite of Python-based utility scripts for deploying, patching, and diagnosing LoRaWAN BasicStation components on Teltonika RUTM-series routers.

## 🛠 Deployment and Installation

These tools handle the transfer and installation of packages on the target device.

| Tool | Description |
| :--- | :--- |
| `deploy_api.py` | Specifically deploys and verifies the `vuci-app-basicstation-api` package. |
| `deploy_packages.sh` | Bash script for manual bulk transfer of IPK packages to the device. |
| `deploy_clean.py` | Performs a clean removal of UI and API packages followed by a fresh installation. |
| `deploy_final.py` | The main deployment script for the final version of the BasicStation suite. |
| `deploy_overlay.py` | Deploys a writable overlay for testing API changes without permanent installation. |
| `deploy_recovery.py` | Used to recover if a deployment fails or leaves the system in an inconsistent state. |
| `opkg_strict_deploy.py` | A stricter deployment script that ensures all dependency constraints are met. |
| `clean_install.py` | Utility to clean and reinstall the entire BasicStation bundle. |
| `strict_reinstall.py` | Reinstalls all components with strict version and dependency checks. |

## 🧩 Patching and Verification

Tools for patching the minified UI (BasicStation Vue component) and verifying configurations.

| Tool | Description |
| :--- | :--- |
| `brute_patch.py` | Directly patches minified JS files on the device to fix UCI API routing. |
| `fix_all_js.py` | Scans and patches all BasicStation-related JS bundles on the system. |
| `hunt_js.py` | Searches for specific hardcoded strings or patterns in the minified UI. |
| `hunt_and_patch.py` | Automated hunt for UI patterns followed by an immediate patch application. |
| `read_js.py` | Diagnostic tool to read and format zzipped JS files from the device. |
| `final_hunt.py` | A final sweep to ensure all known UI issues are addressed. |

## 🔍 Diagnostics and Debugging

Standard tools for verifying connectivity, environment variables, and device status.

| Tool | Description |
| :--- | :--- |
| `debug_device.py` | General-purpose diagnostic script for checking BasicStation service health. |
| `debug_ui.py` | Validates the integrity of the UI files and their interaction with the API. |
| `diag_ssh.py` | Verifies SSH connectivity and basic shell execution on the target. |
| `final_verify_env.py` | Confirms all sensitive environment variables are correctly loaded and reachable. |
| `check_files.py` | Audits the presence and permissions of critical BasicStation configuration and binary files. |

## ⚙ Usage

Most scripts are designed to be run from the project root using `python3`:

```bash
python3 avp_tools/deploy_final.py
```

### Configuration

All tools utilize the shared connection and authentication settings defined in the project's `.env` file via the `util/env_config.py` module.
