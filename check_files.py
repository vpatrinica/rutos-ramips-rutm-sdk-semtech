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

    paths = ["/www/views/services", "/usr/local/www/views/services"]
    for p in paths:
        print(f"--- Checking {p} ---")
        out, _ = execute(ssh, f"ls {p}")
        print(f"Files: {out}")
        
        # Check content for /api/uci
        out, _ = execute(ssh, f"zcat {p}/Basicstation_*.js.gz | grep -a -o '/api/uci' | head -n 1")
        print(f"Contains /api/uci: {'YES' if out else 'NO'}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")