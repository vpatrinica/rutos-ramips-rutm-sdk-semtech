import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent / "util"
sys.path.append(str(util_path))
from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS

import paramiko
import time

def execute(ssh, cmd):
    print(f"Executing: {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8', 'ignore').strip()
    err = stderr.read().decode('utf-8', 'ignore').strip()
    if out: print(f"  Out: {out}")
    if err: print(f"  Err: {err}")
    return out, err

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(DEVICE_IP, username=DEVICE_USER, password=DEVICE_PASS, allow_agent=False, look_for_keys=False)

    print("--- 1. CLEANUP: Removing overlays and packages ---")
    # Clean up the hacks to prevent 404s/conflicts
    execute(ssh, "umount -l /www || true")
    execute(ssh, "umount -l /usr/lib/lua/api/services || true")
    execute(ssh, "rm -rf /tmp/www_overlay /tmp/api_services_overlay")
    
    # Strictly follow: remove UI first, then API
    execute(ssh, "opkg remove vuci-app-basicstation-ui --force-remove")
    execute(ssh, "opkg remove vuci-app-basicstation-api --force-depends --force-remove")

    print("--- 2. UPLOADING FRESH PACKAGES ---")
    sftp = ssh.open_sftp()
    sftp.put('bin/packages/mipsel_24kc/vuci/vuci-app-basicstation-api_4_mipsel_24kc.ipk', '/tmp/api.ipk')
    sftp.put('avp_bundle/vuci-app-basicstation-ui_7_mipsel_24kc.ipk', '/tmp/ui.ipk')
    sftp.close()

    print("--- 3. INSTALLING: API then UI ---")
    # Install API first
    execute(ssh, "opkg install /tmp/api.ipk")
    # Then install UI
    execute(ssh, "opkg install /tmp/ui.ipk")

    print("--- 4. RESTARTING SERVICES ---")
    execute(ssh, "/etc/init.d/uhttpd restart")
    execute(ssh, "/etc/init.d/basicstation restart")

    print("--- 5. VERIFICATION ---")
    execute(ssh, "opkg status vuci-app-basicstation-api")
    execute(ssh, "opkg status vuci-app-basicstation-ui")
    execute(ssh, "ls -l /usr/lib/lua/api/services/basicstation.lua")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")