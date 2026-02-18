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

    print("--- 1. Overriding /www with writable tmpfs ---")
    # We must do this every time if it's lost, or just ensure it's there
    execute(ssh, "mkdir -p /tmp/www_overlay")
    execute(ssh, "cp -a /www/* /tmp/www_overlay/")
    execute(ssh, "mount --bind /tmp/www_overlay /www")
    
    print("--- 2. Placing UI files ---")
    execute(ssh, "mkdir -p /www/views/services")
    # Extraction was already done locally in previous step, files are in /tmp/ui_extract
    sftp = ssh.open_sftp()
    ui_js_local = "/tmp/ui_extract/www/views/services/Basicstation_9c1611.js.gz"
    ui_css_local = "/tmp/ui_extract/www/views/services/Basicstation_9c1611.css.gz"
    sftp.put(ui_js_local, '/www/views/services/Basicstation_9c1611.js.gz')
    sftp.put(ui_css_local, '/www/views/services/Basicstation_9c1611.css.gz')

    print("--- 3. Restarting Services ---")
    execute(ssh, "/etc/init.d/uhttpd restart")
    
    print("--- 4. Final verification ---")
    out, _ = execute(ssh, "ls -l /www/views/services/Basicstation_9c1611.js.gz")
    print(f"UI JS Check: {out}")
    out2, _ = execute(ssh, "grep 'v12' /usr/lib/lua/api/services/basicstation.lua")
    print(f"API Check: {out2}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")