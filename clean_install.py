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

    # 1. Unmount and clean overlay
    execute(ssh, "umount /www || true")
    execute(ssh, "opkg remove vuci-app-basicstation-ui --force-remove")
    execute(ssh, "rm -rf /overlay/root/upper/www/views/services/Basicstation*")
    execute(ssh, "rm -rf /overlay/root/upper/usr/local/www/views/services/Basicstation*")

    # 2. Re-upload fresh IPK
    print("Uploading fresh IPK...")
    sftp = ssh.open_sftp()
    sftp.put('avp_bundle/vuci-app-basicstation-ui_7_mipsel_24kc.ipk', '/tmp/vuci-app-basicstation-ui.ipk')
    sftp.close()

    # 3. Install
    execute(ssh, "opkg install /tmp/vuci-app-basicstation-ui.ipk")

    # 4. Patch the JS directly on device to BE SURE
    # We hunt for the pattern where "basicstation" is set as config and force api:"/api/uci"
    out, _ = execute(ssh, "find /www -name 'Basicstation_*.js.gz'")
    files = out.split('\n')
    for f in files:
        if not f: continue
        print(f"Forcing patch on {f}")
        execute(ssh, f"zcat {f} > /tmp/p.js")
        # Replace config:"basicstation" with api:"/api/uci",config:"basicstation"
        execute(ssh, "sed -i 's/config:\"basicstation\"/api:\"\\/api\\/uci\",config:\"basicstation\"/g' /tmp/p.js")
        # Replace explicit axios base paths
        execute(ssh, "sed -i 's/\\/api\\/basicstation\\/config/\\/api\\/uci/g' /tmp/p.js")
        execute(ssh, f"gzip -c /tmp/p.js > {f}")

    # 5. Clear caches and restart
    execute(ssh, "/etc/init.d/uhttpd restart")
    
    ssh.close()
    print("\nClean installation and patching complete.")
except Exception as e:
    print(f"Error: {e}")