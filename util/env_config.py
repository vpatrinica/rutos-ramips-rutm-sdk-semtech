"""Shared environment configuration for BasicStation utilities.

Loads DEVICE_IP, DEVICE_USER, and DEVICE_PASS from the project .env file,
falling back to environment variables, then defaults.

Usage:
    from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS, SSH_OPTS
"""

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = ROOT / ".env"

# Defaults (overridden by .env or environment)
_DEFAULTS = {
    "DEVICE_IP": "192.168.1.1",
    "DEVICE_USER": "root",
    "DEVICE_PASS": "",
}


def _load_env():
    """Load .env file into os.environ (does not override existing vars)."""
    if not ENV_FILE.exists():
        return
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        # Don't override existing environment variables
        if key not in os.environ:
            os.environ[key] = value


_load_env()

DEVICE_IP = os.environ.get("DEVICE_IP", _DEFAULTS["DEVICE_IP"])
DEVICE_USER = os.environ.get("DEVICE_USER", _DEFAULTS["DEVICE_USER"])
DEVICE_PASS = os.environ.get("DEVICE_PASS", _DEFAULTS["DEVICE_PASS"])

SSH_OPTS = ["-o", "StrictHostKeyChecking=no"]
