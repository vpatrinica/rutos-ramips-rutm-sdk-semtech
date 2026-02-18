import paramiko
import sys
import time
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent.parent / "util"
sys.path.append(str(util_path))
from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS


def execute(ssh, cmd):
    print(f"Executing: {cmd}")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode("utf-8", "ignore").strip()
    err = stderr.read().decode("utf-8", "ignore").strip()
    if out:
        print(f"  Out: {out}")
    if err:
        print(f"  Err: {err}")
    return out, err


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

    print("--- 1. Removing UI and API packages ---")
    execute(ssh, "opkg remove vuci-app-basicstation-ui --force-remove")
    execute(ssh, "opkg remove vuci-app-basicstation-api --force-depends --force-remove")

    print("--- 2. Cleaning overlay and unmounting ---")
    execute(ssh, "umount /usr/lib/lua/api/services || true")
    execute(ssh, "umount /www || true")
    execute(ssh, "rm -rf /overlay/root/upper/usr/lib/lua/api/services/basicstation.lua")
    execute(ssh, "rm -rf /overlay/root/upper/www/views/services/Basicstation*")

    print("--- 3. Uploading fresh IPKs ---")
    sftp = ssh.open_sftp()
    sftp.put(
        "bin/packages/mipsel_24kc/vuci/vuci-app-basicstation-api_4_mipsel_24kc.ipk",
        "/tmp/vuci-app-basicstation-api.ipk",
    )
    sftp.put(
        "avp_bundle/vuci-app-basicstation-ui_7_mipsel_24kc.ipk",
        "/tmp/vuci-app-basicstation-ui.ipk",
    )
    sftp.close()

    print("--- 4. Installing API then UI ---")
    # Using --force-reinstall to be absolutely sure
    execute(ssh, "opkg install /tmp/vuci-app-basicstation-api.ipk --force-reinstall")
    execute(ssh, "opkg install /tmp/vuci-app-basicstation-ui.ipk --force-reinstall")

    print("--- 5. Restarting services ---")
    execute(ssh, "/etc/init.d/uhttpd restart")
    execute(ssh, "/etc/init.d/basicstation restart")

    print("--- 6. Verification ---")
    out, _ = execute(ssh, "grep 'v12' /usr/lib/lua/api/services/basicstation.lua")
    if out:
        print(f"Verified Version: {out}")
    else:
        print("Verification FAILED: Correct version not found on device path.")
        print("Checking if file exists at all...")
        out2, _ = execute(ssh, "ls -l /usr/lib/lua/api/services/basicstation.lua")
        print(f"File status: {out2}")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")
