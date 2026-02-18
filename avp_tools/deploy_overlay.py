import paramiko
import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent.parent / "util"
sys.path.append(str(util_path))
from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS


def execute(ssh, cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    return stdout.read().decode().strip(), stderr.read().decode().strip()


try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        DEVICE_IP,
        username=DEVICE_USER,
        password=DEVICE_PASS,
        allow_agent=False,
        look_for_keys=False,
    )

    print("--- 1. Uploading file to /tmp ---")
    sftp = ssh.open_sftp()
    local_path = "package/feeds/vuci/vuci-app-basicstation-api/files/usr/lib/lua/api/services/basicstation.lua"
    sftp.put(local_path, "/tmp/basicstation.lua")
    sftp.close()

    print("--- 2. Creating writable overlay for API services ---")
    # Prepare a writable directory structure in /tmp (RAM)
    execute(ssh, "mkdir -p /tmp/api_services_overlay")
    # Copy existing services (so we don't break other things)
    execute(ssh, "cp -a /usr/lib/lua/api/services/* /tmp/api_services_overlay/")
    # Copy our new service in
    execute(ssh, "cp /tmp/basicstation.lua /tmp/api_services_overlay/")

    print("--- 3. Applying Bind Mount ---")
    # Bind mount the writable directory over the read-only one
    out, err = execute(
        ssh, "mount --bind /tmp/api_services_overlay /usr/lib/lua/api/services"
    )
    if err:
        print(f"Mount error: {err}")

    print("--- 4. Restarting uhttpd ---")
    execute(ssh, "/etc/init.d/uhttpd restart")

    print("--- 5. Verification ---")
    out, _ = execute(
        ssh,
        "grep 'BASICSTATION SERVICE LOADED v10' /usr/lib/lua/api/services/basicstation.lua",
    )
    if out:
        print("SUCCESS: File verification passed!")
        print(out)
    else:
        print("FAILURE: File not found or content mismatch.")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")
