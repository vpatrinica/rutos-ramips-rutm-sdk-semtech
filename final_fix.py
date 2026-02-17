import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent / "util"
sys.path.append(str(util_path))
from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS

import paramiko

def execute(ssh, cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    return stdout.read().decode('utf-8', 'ignore').strip(), stderr.read().decode('utf-8', 'ignore').strip()

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(DEVICE_IP, username=DEVICE_USER, password=DEVICE_PASS, allow_agent=False, look_for_keys=False)

    print("--- 1. Identifying the active hash ---")
    # VUCI often puts the hashes in index.html or a manifest. We'll search assets for the load string.
    out, _ = execute(ssh, "zgrep -a -o 'Basicstation_[a-z0-9]*' /www/assets/*.js.gz | head -n 5")
    print(f"Active hash search:\n{out}")
    
    # If we can't find it that way, we'll just patch EVERY Basicstation file in /www
    out, _ = execute(ssh, "find /www -name 'Basicstation_*.js.gz'")
    files = out.split('\n')
    
    for f in files:
        if not f: continue
        print(f"Patching {f}...")
        execute(ssh, f"zcat {f} > /tmp/p.js")
        # Ensure it uses /api/uci for all forms
        # We look for the vuci-form pattern and insert the api prop
        execute(ssh, "sed -i 's/config:\"basicstation\"/api:\"\\/api\\/uci\",config:\"basicstation\"/g' /tmp/p.js")
        # Also catch any explicit axios calls
        execute(ssh, "sed -i 's/\\/api\\/basicstation\\/config/\\/api\\/uci/g' /tmp/p.js")
        execute(ssh, f"gzip -c /tmp/p.js > {f}")
        print(f"  Verified: {execute(ssh, f'zcat {f} | grep -a -o \"/api/uci\" | head -n 1')[0]}")

    print("\n--- 2. Final Config Application ---")
    execute(ssh, "uci set basicstation.station.stationid='0016C001F118FA32'")
    execute(ssh, "uci set basicstation.auth.token='NNSXS.W6DIAXZDSEWWPIQC644Z3HE7CVJDRVWUDQUG3MY'")
    execute(ssh, "uci commit basicstation")
    execute(ssh, "/etc/init.d/basicstation restart")
    print("Station restarted.")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")