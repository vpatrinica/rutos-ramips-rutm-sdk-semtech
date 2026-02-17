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

    print("--- 1. CLEANING PREVIOUS STATE ---")
    # Unmount any remaining bind mounts
    execute(ssh, "umount -l /www || true")
    execute(ssh, "umount -l /usr/lib/lua/api/services || true")
    execute(ssh, "umount -l /usr/share/vuci/path.d || true")

    # Strictly follow instructions: remove UI first, then API
    print("--- 2. REMOVING PACKAGES ---")
    execute(ssh, "opkg remove vuci-app-basicstation-ui --force-remove")
    execute(ssh, "opkg remove vuci-app-basicstation-api --force-depends --force-remove")
    
    # Cleanup overlays for these packages
    execute(ssh, "rm -rf /overlay/root/upper/www/views/services/Basicstation*")
    execute(ssh, "rm -rf /overlay/root/upper/usr/lib/lua/api/services/basicstation.lua")
    execute(ssh, "rm -rf /overlay/root/upper/usr/share/vuci/path.d/vuci-app-basicstation.json")

    print("--- 3. UPLOADING FRESH IPKS ---")
    sftp = ssh.open_sftp()
    sftp.put('bin/packages/mipsel_24kc/vuci/vuci-app-basicstation-api_4_mipsel_24kc.ipk', '/tmp/api.ipk')
    sftp.put('avp_bundle/vuci-app-basicstation-ui_7_mipsel_24kc.ipk', '/tmp/ui.ipk')
    sftp.close()

    print("--- 4. INSTALLING PACKAGES (API THEN UI) ---")
    execute(ssh, "opkg install /tmp/api.ipk")
    execute(ssh, "opkg install /tmp/ui.ipk")

    print("--- 5. RESTARTING SERVICES ---")
    execute(ssh, "/etc/init.d/uhttpd restart")
    execute(ssh, "/etc/init.d/basicstation restart")
    
    print("--- 6. FINAL CHECK ---")
    execute(ssh, "opkg list-installed | grep basicstation")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")