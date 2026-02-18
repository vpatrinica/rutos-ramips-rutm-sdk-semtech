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
    # Disable agent and look for keys to avoid signing errors
    ssh.connect(DEVICE_IP, username=DEVICE_USER, password=DEVICE_PASS, allow_agent=False, look_for_keys=False)

    print("--- Checking Active Mounts ---")
    out, err = execute(ssh, "mount | grep /www")
    print(out if out else "No /www bind mounts found")

    print("\n--- Searching for all Basicstation related files in /www ---")
    out, err = execute(ssh, "find /www -name '*Basicstation*'")
    print(out if out else "No files found")

    print("\n--- Checking index.html for component loading ---")
    # index.html might be gzipped
    execute(ssh, "zcat /www/index.html.gz > /tmp/index.html")
    out, err = execute(ssh, "grep -o 'Basicstation_[a-z0-9]*' /tmp/index.html")
    print(f"Components in index.html: {out}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")