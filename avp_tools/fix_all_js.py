import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent.parent / "util"
sys.path.append(str(util_path))
from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS

import paramiko

def execute(ssh, cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    return stdout.read().decode().strip(), stderr.read().decode().strip()

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(DEVICE_IP, username=DEVICE_USER, password=DEVICE_PASS, allow_agent=False, look_for_keys=False)

    print("--- 1. Determining active hash ---")
    # Search in all assets for which Basicstation version is referenced
    out, _ = execute(ssh, "zgrep -a -o 'Basicstation_[a-z0-9]*' /www/assets/*.js.gz | sort | uniq -c")
    print(f"Referenced hashes:\n{out}")

    print("\n--- 2. Checking the content of the JS files (unzipped) ---")
    files = [
        "/www/views/services/Basicstation_4f2bd8.js.gz",
        "/www/views/services/Basicstation_5176d4.js.gz",
        "/www/views/services/Basicstation_9c1611.js.gz"
    ]
    
    for f in files:
        print(f"Testing {f}...")
        # Check if the bad API string exists in this file
        # The JS likely has "/api/basicstation/config"
        # We want to replace it with "/api/uci"
        # But wait, vuci-form automatically constructs the URL if api is not set.
        # It likely looks like 'api:"/api/basicstation"' or similar in the minified JS.
        
        out, _ = execute(ssh, f"zcat {f} | grep -a -o 'api:\"[^\"]*\"'")
        print(f"  Found 'api' strings: {out}")

    print("\n--- 3. Forcing /api/uci into all variations ---")
    # We will replace the default API path with /api/uci everywhere it appears in these files
    # Typical minified Vue might have: config:"basicstation"
    # We want to change that to: config:"basicstation",api:"/api/uci"
    for f in files:
        print(f"Processing {f}...")
        execute(ssh, f"zcat {f} > /tmp/temp.js")
        # Perform replacement: replace 'config:"basicstation"' with 'config:"basicstation",api:"/api/uci"'
        # Using sed to find the pattern and append the api property
        execute(ssh, "sed -i 's/config:\"basicstation\"/config:\"basicstation\",api:\"\\/api\\/uci\"/g' /tmp/temp.js")
        # Re-gzip and replace
        execute(ssh, f"gzip -c /tmp/temp.js > {f}")
        print(f"  Updated {f}")

    print("\n--- 4. Verification ---")
    for f in files:
        out, _ = execute(ssh, f"zcat {f} | grep -a -o 'api:\"/api/uci\"'")
        print(f"  Verification for {f}: {out}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")