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

    f = "/www/views/services/Basicstation_9c1611.js.gz"
    print(f"--- Analyzing {f} ---")
    
    # Read the file
    content, _ = execute(ssh, f"zcat {f}")
    
    # We saw earlier it has axios calls to /api/basicstation
    # We want to catch the form config. In minified vue it might be {config:"basicstation"}
    # or sometimes just "basicstation" passed to a function.
    
    if "basicstation" in content:
        print("Found 'basicstation' in content.")
        # Find occurrences with some context
        import re
        matches = [m.start() for m in re.finditer('basicstation', content)]
        for m in matches:
            print(f"Context: {content[max(0, m-20):m+50]}")

    # Forcing a broad patch: replace 'basicstation' with something that includes api:'/api/uci'
    # if it looks like a config object.
    # We'll try to find 'config:"basicstation"' even if grep failed (maybe spacing?)
    new_content = content.replace('config:"basicstation"', 'api:"/api/uci",config:"basicstation"')
    # And catch the axios paths
    new_content = new_content.replace('/api/basicstation/config', '/api/uci')
    
    if new_content != content:
        print("Content changed! Writing back...")
        # Write to temp file on device
        ftp = ssh.open_sftp()
        with ftp.file('/tmp/patched.js', 'w') as remote_file:
            remote_file.write(new_content)
        ftp.close()
        
        execute(ssh, f"gzip -c /tmp/patched.js > {f}")
        print("Patch applied and gzipped.")
    else:
        print("No changes made by string replacement.")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")