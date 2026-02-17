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

    print("--- Searching for any axios-like calls to basicstation ---")
    # Axios/fetch calls might be dynamically constructed. 
    # Browser says PUT http://.../api/basicstation/config/station
    # VUCI often does `this.$axios.put('/api/basicstation/config/station', ...)`
    
    # Search for parts of the URL
    out, _ = execute(ssh, "zgrep -l '/api/basicstation' /www/assets/*.js.gz /www/views/services/*.js.gz")
    print(f"Files containing '/api/basicstation':\n{out}")

    if out:
        files = out.split('\n')
        for f in files:
            print(f"\nChecking {f}...")
            # Look for the axios call pattern
            content, _ = execute(ssh, f"zcat {f}")
            if 'config/station' in content:
                print("  !!! FOUND 'config/station' !!!")
            elif 'config/' in content:
                idx = content.find('config/')
                print(f"  Found 'config/' at {idx}. Context: {content[idx:idx+50]}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")