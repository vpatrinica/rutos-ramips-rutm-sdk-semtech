import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent.parent / "util"
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

    print("--- 1. Manual extraction and placement ---")
    # We will manually put the files because opkg database is read-only
    sftp = ssh.open_sftp()
    
    # Place API
    local_lua = "package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua"
    sftp.put(local_lua, '/tmp/basicstation.lua')
    
    # Create directory if missing (it exists but overlay might be weird)
    execute(ssh, "mkdir -p /usr/lib/lua/api/services")
    # Use dd to write to the file path to bypass some mount/open issues
    execute(ssh, "cat /tmp/basicstation.lua > /usr/lib/lua/api/services/basicstation.lua")
    
    # Place UI - extraction locally first
    os.system("mkdir -p /tmp/ui_extract && tar -xzf avp_bundle/vuci-app-basicstation-ui_7_mipsel_24kc.ipk -C /tmp/ui_extract")
    os.system("tar -xzf /tmp/ui_extract/data.tar.gz -C /tmp/ui_extract")
    
    # Upload UI files (we know they are in www/views/services/)
    execute(ssh, "mkdir -p /www/views/services")
    ui_js_local = "/tmp/ui_extract/www/views/services/Basicstation_9c1611.js.gz"
    ui_css_local = "/tmp/ui_extract/www/views/services/Basicstation_9c1611.css.gz"
    
    sftp.put(ui_js_local, '/tmp/Basicstation_9c1611.js.gz')
    sftp.put(ui_css_local, '/tmp/Basicstation_9c1611.css.gz')
    
    execute(ssh, "cat /tmp/Basicstation_9c1611.js.gz > /www/views/services/Basicstation_9c1611.js.gz")
    execute(ssh, "cat /tmp/Basicstation_9c1611.css.gz > /www/views/services/Basicstation_9c1611.css.gz")

    print("--- 2. Restarting services ---")
    execute(ssh, "/etc/init.d/uhttpd restart")
    execute(ssh, "/etc/init.d/basicstation restart")
    
    print("--- 3. Verification ---")
    out, _ = execute(ssh, "grep 'v12' /usr/lib/lua/api/services/basicstation.lua")
    print(f"Verified API: {out}")
    
    ssh.close()
    sftp.close()
except Exception as e:
    print(f"Error: {e}")