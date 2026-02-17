#!/usr/bin/env python3
"""BasicStation device diagnostic tool.

Connects to a Teltonika RUTM device and collects diagnostic information
about the BasicStation service: running status, log tail, UCI config,
package versions, and file permissions.

Usage:
    python3 diag.py                      # full diagnostic
    python3 diag.py --logs               # show last 50 log lines
    python3 diag.py --config             # show UCI config
    python3 diag.py --status             # service status only
    python3 diag.py --host 192.168.1.1   # custom device IP
"""

import argparse
import os
import subprocess

from env_config import DEVICE_IP, DEVICE_PASS, DEVICE_USER, SSH_OPTS


def ssh_cmd(host, user, command):
    """Run command on device, return stdout."""
    env = os.environ.copy()
    env["SSHPASS"] = DEVICE_PASS
    result = subprocess.run(
        ["sshpass", "-e", "ssh", *SSH_OPTS, f"{user}@{host}", command],
        capture_output=True,
        text=True,
        env=env,
    )
    return result.stdout.strip()


def section(title):
    """Print section header."""
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


def show_status(host, user):
    """Show service status."""
    section("Service Status")
    out = ssh_cmd(host, user, "pgrep -fa station || echo 'NOT RUNNING'")
    print(out)
    out = ssh_cmd(
        host, user, "ls -la /tmp/basicstation/log 2>/dev/null || echo 'No log file'"
    )
    print(f"\nLog file: {out}")
    out = ssh_cmd(
        host,
        user,
        "ls -la /tmp/basicstation/station.conf 2>/dev/null || echo 'No station.conf'",
    )
    print(f"Config:   {out}")


def show_packages(host, user):
    """Show installed package versions."""
    section("Installed Packages")
    pkgs = [
        "libmbedtls21",
        "sx1302_hal-utils",
        "lora-basicstation",
        "vuci-app-basicstation-api",
        "vuci-app-basicstation-ui",
    ]
    for pkg in pkgs:
        ver = ssh_cmd(
            host,
            user,
            f"opkg info {pkg} 2>/dev/null | grep Version || echo 'NOT INSTALLED'",
        )
        print(f"  {pkg}: {ver}")


def show_config(host, user):
    """Show UCI config."""
    section("UCI Config (/etc/config/basicstation)")
    out = ssh_cmd(
        host, user, "uci show basicstation 2>/dev/null || cat /etc/config/basicstation"
    )
    print(out)


def show_logs(host, user, lines=50):
    """Show last N log lines."""
    section(f"Log (last {lines} lines)")
    out = ssh_cmd(
        host,
        user,
        f"tail -n {lines} /tmp/basicstation/log 2>/dev/null || echo 'No log file'",
    )
    print(out)


def show_permissions(host, user):
    """Show critical file permissions."""
    section("File Permissions")
    files = [
        "/tmp/basicstation/log",
        "/etc/config/basicstation",
        "/etc/basicstation/",
        "/usr/local/usr/lib/lua/api/services/basicstation.lua",
    ]
    for f in files:
        out = ssh_cmd(host, user, f"ls -la {f} 2>/dev/null || echo 'MISSING: {f}'")
        print(f"  {out}")


def main():
    parser = argparse.ArgumentParser(description="BasicStation device diagnostics")
    parser.add_argument("--host", default=DEVICE_IP, help="Device IP")
    parser.add_argument("--user", default=DEVICE_USER, help="SSH user")
    parser.add_argument("--logs", action="store_true", help="Show logs only")
    parser.add_argument("--config", action="store_true", help="Show config only")
    parser.add_argument("--status", action="store_true", help="Show status only")
    parser.add_argument("--lines", type=int, default=50, help="Log lines to show")
    args = parser.parse_args()

    if args.logs:
        show_logs(args.host, args.user, args.lines)
        return
    if args.config:
        show_config(args.host, args.user)
        return
    if args.status:
        show_status(args.host, args.user)
        return

    # Full diagnostic
    print("BasicStation Device Diagnostic")
    print(f"Device: {args.user}@{args.host}")
    show_status(args.host, args.user)
    show_packages(args.host, args.user)
    show_permissions(args.host, args.user)
    show_config(args.host, args.user)
    show_logs(args.host, args.user, args.lines)
    print(f"\n{'=' * 60}")
    print("  Diagnostic complete")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
