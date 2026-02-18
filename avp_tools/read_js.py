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

    print("--- Reading Basicstation_9c1611.js.gz ---")
    out, _ = execute(ssh, "zcat /www/views/services/Basicstation_9c1611.js.gz")
    # Take a chunk that contains "basicstation"
    idx = out.find("basicstation")
    if idx != -1:
        print(f"Context around 'basicstation':\n{out[max(0, idx-50):idx+100]}")
    else:
        print("String 'basicstation' not found in file!")
        # Print first 200 chars anyway
        print(f"Start of file:\n{out[:200]}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")