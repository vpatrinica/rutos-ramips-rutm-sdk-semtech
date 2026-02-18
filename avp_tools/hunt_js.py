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

    print("--- Hunting for the 501-causing JS ---")
    # Search in all assets and views for the string "config/station" which we see in the error
    out, _ = execute(ssh, "zgrep -l 'config/station' /www/assets/*.js.gz /www/views/services/*.js.gz")
    print(f"Files containing 'config/station':\n{out}")
    
    # Let's look at the first match more closely
    if out:
        first_file = out.split('\n')[0]
        print(f"\n--- Context in {first_file} ---")
        # Find context around "config/station"
        content, _ = execute(ssh, f"zcat {first_file}")
        idx = content.find("config/station")
        if idx != -1:
            print(content[max(0, idx-100):idx+200])

    ssh.close()
except Exception as e:
    print(f"Error: {e}")