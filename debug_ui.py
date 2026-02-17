import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent / "util"
sys.path.append(str(util_path))
from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS

import paramiko
import os

def execute(ssh, cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    return stdout.read().decode().strip(), stderr.read().decode().strip()

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(DEVICE_IP, username=DEVICE_USER, password=DEVICE_PASS, allow_agent=False, look_for_keys=False)

    print("--- 1. Web Root Content ---")
    out, _ = execute(ssh, "ls -F /www/")
    print(out)

    print("\n--- 2. Searching for Basicstation hashes ---")
    # Search in JS files for the string "Basicstation_" to see what the router thinks it should load
    out, _ = execute(ssh, "zgrep -a -o 'Basicstation_[a-z0-9]*' /www/assets/*.js.gz | sort -u")
    print(f"Hashes found in assets: \n{out}")

    print("\n--- 3. Checking /www/views/services content ---")
    out, _ = execute(ssh, "ls -l /www/views/services/Basicstation*")
    print(out)

    print("\n--- 4. Checking if my 'api=\"/api/uci\"' change is in the files ---")
    # Search for the string I added in the JS files
    out, _ = execute(ssh, "zgrep -l '/api/uci' /www/views/services/Basicstation*.js.gz")
    print(f"Files containing /api/uci: \n{out}")
    
    # Also check for the old bad API string
    out, _ = execute(ssh, "zgrep -l '/api/basicstation/config' /www/views/services/Basicstation*.js.gz")
    print(f"Files containing old bad API: \n{out}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")