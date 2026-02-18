import paramiko
import os

# Manual .env loader
def load_env_manual(path=".env"):
    if os.path.exists(path):
        with open(path) as f:
            for line in f:
                if line.strip() and not line.startswith("#"):
                    key, value = line.strip().split("=", 1)
                    os.environ[key] = value

load_env_manual()

ip = os.getenv('DEVICE_IP')
user = os.getenv('DEVICE_USER')
password = os.getenv('DEVICE_PASS')
station_id = os.getenv('STATION_ID')
lns_token = os.getenv('LNS_TOKEN')

def execute(ssh, cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    return stdout.read().decode('utf-8', 'ignore').strip(), stderr.read().decode('utf-8', 'ignore').strip()

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, username=user, password=password, allow_agent=False, look_for_keys=False)

    print(f"--- 1. Verification of Packages on {ip} ---")
    out, _ = execute(ssh, "opkg list-installed | grep basicstation")
    print(out)

    print("\n--- 2. Applying Configuration from .env ---")
    execute(ssh, f"uci set basicstation.station.stationid='{station_id}'")
    execute(ssh, f"uci set basicstation.auth.token='{lns_token}'")
    execute(ssh, "uci commit basicstation")
    execute(ssh, "/etc/init.d/basicstation restart")
    print(f"Configuration committed for Station ID: {station_id}")

    print("\n--- 3. Checking API File Status ---")
    # Checking both standard and local paths
    out, _ = execute(ssh, "ls -l /usr/lib/lua/api/services/basicstation.lua /usr/local/usr/lib/lua/api/services/basicstation.lua 2>/dev/null")
    print(f"API Files:\n{out}")

    ssh.close()
    print("\nVerification and configuration complete.")
except Exception as e:
    print(f"Error: {e}")
