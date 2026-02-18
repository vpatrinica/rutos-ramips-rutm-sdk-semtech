import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent.parent / "util"
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

    print("--- 1. Searching for all JS.gz files ---")
    out, _ = execute(ssh, "find /www -name '*.js.gz'")
    files = out.split('\n')
    print(f"Found {len(files)} files.")

    print("\n--- 2. Manually checking each file for '/api/basicstation' ---")
    for f in files:
        if not f: continue
        out, _ = execute(ssh, f"zcat {f} | grep -a -c '/api/basicstation'")
        if out and int(out) > 0:
            print(f"File {f} has {out} matches.")
            # Check for config/
            out2, _ = execute(ssh, f"zcat {f} | grep -a -c 'config/'")
            print(f"  ...and {out2} matches for 'config/'.")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")