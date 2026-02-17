import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent / "util"
sys.path.append(str(util_path))
from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS

import paramiko
import os

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

    # 1. Force Remove
    execute(ssh, "opkg remove vuci-app-basicstation-api --force-depends")
    
    # 2. Upload fresh IPK (reusing the one we uploaded or uploading again just in case)
    local_ipk = "bin/packages/mipsel_24kc/vuci/vuci-app-basicstation-api_4_mipsel_24kc.ipk"
    sftp = ssh.open_sftp()
    sftp.put(local_ipk, '/tmp/vuci-app-basicstation-api.ipk')
    sftp.close()

    # 3. Force Install
    execute(ssh, "opkg install /tmp/vuci-app-basicstation-api.ipk --force-reinstall --force-downgrade")

    # 4. Restart uhttpd
    execute(ssh, "/etc/init.d/uhttpd restart")
    
    # 5. Verify
    out, _ = execute(ssh, "grep 'BASICSTATION SERVICE LOADED' /usr/lib/lua/api/services/basicstation.lua")
    print(f"Verification Check: {out}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")