#!/usr/bin/env python3
"""BasicStation deployment utility.

Builds, bundles, and deploys the LoRaWAN BasicStation packages to a
Teltonika RUTM device over SSH/SCP.

Usage:
    python3 deploy.py                        # full deploy (build + deploy)
    python3 deploy.py --skip-build           # deploy existing IPKs only
    python3 deploy.py --ui-only              # rebuild & deploy UI package only
    python3 deploy.py --lua-only             # SCP Lua API file directly (fastest)
    python3 deploy.py --host 192.168.1.1     # custom device IP
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from env_config import DEVICE_IP, DEVICE_PASS, DEVICE_USER, ROOT, SSH_OPTS

PACKAGES = [
    ("libmbedtls21", "package/libs/mbedtls"),
    ("sx1302_hal-utils", "package/libs/sx1302_hal"),
    ("lora-basicstation", "package/feeds/packages/lora-basicstation"),
    ("vuci-app-basicstation-api", "package/feeds/vuci/vuci-app-basicstation-api"),
    ("vuci-app-basicstation-ui", "package/feeds/vuci/vuci-app-basicstation-ui"),
]

IPK_PATTERN = re.compile(r"basicstation|lora|mbedtls|sx1302")

LUA_SRC = (
    "package/feeds/vuci/vuci-app-basicstation-api"
    "/files/usr/lib/lua/api/services/basicstation.lua"
)
LUA_DST = "/usr/local/usr/lib/lua/api/services/basicstation.lua"


def run(cmd, cwd=None, check=True):
    """Run a command, printing it first."""
    print(f"  $ {' '.join(cmd)}")
    env = os.environ.copy()
    env["SSHPASS"] = DEVICE_PASS
    return subprocess.run(cmd, cwd=cwd or ROOT, check=check, env=env)


def scp(src, dst_path, host, user):
    """SCP a file to device."""
    run(["sshpass", "-e", "scp", *SSH_OPTS, str(src), f"{user}@{host}:{dst_path}"])


def ssh(host, user, command):
    """Run a command on the device via SSH."""
    return run(
        ["sshpass", "-e", "ssh", *SSH_OPTS, f"{user}@{host}", command],
        check=False,
    )


def build_package(pkg_path, clean=True):
    """Build a single OpenWrt package."""
    name = Path(pkg_path).name
    print(f"\n{'=' * 60}")
    print(f"Building {name}...")
    print(f"{'=' * 60}")
    if clean:
        run(["make", f"package/{name}/clean"], cwd=ROOT)
    run(["make", f"package/{name}/compile", "V=s"], cwd=ROOT)


def find_ipks():
    """Find all relevant IPK files in bin/packages/."""
    ipks = []
    bin_dir = ROOT / "bin" / "packages"
    if not bin_dir.exists():
        return ipks
    for ipk in bin_dir.rglob("*.ipk"):
        if IPK_PATTERN.search(ipk.name):
            ipks.append(ipk)
    return sorted(ipks)


def deploy_bundle(host, user):
    """Bundle IPKs, SCP, and install on device."""
    ipks = find_ipks()
    if not ipks:
        print("ERROR: No IPK files found in bin/packages/")
        sys.exit(1)

    print(f"\nFound {len(ipks)} packages:")
    for ipk in ipks:
        print(f"  - {ipk.name}")

    # Create bundle
    bundle_dir = ROOT / "avp_bundle"
    bundle_dir.mkdir(exist_ok=True)
    for ipk in ipks:
        subprocess.run(["cp", str(ipk), str(bundle_dir)], check=True)

    install_script = bundle_dir / "install.sh"
    install_script.write_text(
        "#!/bin/sh\n"
        "echo 'Installing BasicStation and LoRa components...'\n"
        "opkg remove --force-depends lora-basicstation\n"
        "opkg remove --force-depends vuci-app-basicstation-api\n"
        "opkg remove --force-depends vuci-app-basicstation-ui\n"
        "opkg remove --force-depends sx1302_hal-utils\n"
        "opkg remove --force-depends libmbedtls21\n"
        "opkg install libmbedtls21_*.ipk\n"
        "opkg install sx1302_hal-utils_*.ipk\n"
        "opkg install lora-basicstation_*.ipk\n"
        "opkg install vuci-app-basicstation-api_*.ipk\n"
        "opkg install vuci-app-basicstation-ui_*.ipk\n"
        "echo 'Installation complete!'\n"
    )
    install_script.chmod(0o755)

    # Tar, SCP, install
    tar_path = ROOT / "avp_bundle.tar.gz"
    run(["tar", "-czf", str(tar_path), "-C", str(ROOT), "avp_bundle"])
    print(f"\nDeploying to {user}@{host}...")
    scp(tar_path, "/tmp/", host, user)
    ssh(
        host,
        user,
        (
            "mkdir -p /tmp/avp_bundle && "
            "tar -xzf /tmp/avp_bundle.tar.gz -C /tmp/ && "
            "cd /tmp/avp_bundle && chmod +x install.sh && sh ./install.sh && "
            "rm -rf /tmp/avp_bundle /tmp/avp_bundle.tar.gz"
        ),
    )

    # Restart services
    print("\nRestarting services...")
    ssh(host, user, "/etc/init.d/uhttpd restart && /etc/init.d/basicstation restart")
    print("\n✅ Deployment complete!")


def deploy_lua_only(host, user):
    """Fast-path: SCP the Lua API file and restart uhttpd."""
    print("\nFast deploy: Lua API only")
    src = ROOT / LUA_SRC
    if not src.exists():
        print(f"ERROR: {src} not found")
        sys.exit(1)
    scp(src, LUA_DST, host, user)
    ssh(host, user, "/etc/init.d/uhttpd restart")
    print("✅ Lua API deployed and uhttpd restarted!")


def main():
    parser = argparse.ArgumentParser(description="BasicStation deploy utility")
    parser.add_argument("--host", default=DEVICE_IP, help="Device IP")
    parser.add_argument("--user", default=DEVICE_USER, help="SSH user")
    parser.add_argument("--skip-build", action="store_true", help="Skip build step")
    parser.add_argument("--ui-only", action="store_true", help="Build & deploy UI only")
    parser.add_argument("--lua-only", action="store_true", help="SCP Lua file only")
    args = parser.parse_args()

    if args.lua_only:
        deploy_lua_only(args.host, args.user)
        return

    if args.ui_only:
        build_package("package/feeds/vuci/vuci-app-basicstation-ui")
        deploy_bundle(args.host, args.user)
        return

    if not args.skip_build:
        for _name, path in PACKAGES:
            build_package(path)

    deploy_bundle(args.host, args.user)


if __name__ == "__main__":
    main()
