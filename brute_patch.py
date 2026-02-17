import paramiko
import sys
from pathlib import Path

# Add util dir to path to import env_config
util_path = Path(__file__).resolve().parent / "util"
sys.path.append(str(util_path))
from env_config import DEVICE_IP, DEVICE_USER, DEVICE_PASS, STATION_ID, LNS_TOKEN


def execute(ssh, cmd):
    stdin, stdout, stderr = ssh.exec_command(cmd)
    return stdout.read().decode("utf-8", "ignore").strip(), stderr.read().decode(
        "utf-8", "ignore"
    ).strip()


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

    print("--- 1. Overriding /www with writable tmpfs ---")
    # Previous overlay might have been lost or incorrect
    execute(
        ssh,
        "mkdir -p /tmp/www_patch && cp -a /www/* /tmp/www_patch/ && mount --bind /tmp/www_patch /www",
    )

    print("--- 2. Patching all Basicstation JS files ---")
    out, _ = execute(ssh, "find /www/views/services -name 'Basicstation_*.js.gz'")
    files = out.split("\n")

    for f in files:
        if not f:
            continue
        print(f"Patching {f}...")
        execute(ssh, f"zcat {f} > /tmp/p.js")

        # Minified Vue usually looks like n(w,{config:"basicstation"},...
        # We'll replace {config:"basicstation" with {api:"/api/uci",config:"basicstation"
        execute(
            ssh,
            'sed -i \'s/config:"basicstation"/api:"\\/api\\/uci",config:"basicstation"/g\' /tmp/p.js',
        )

        # Also catch explicit axios calls: /api/basicstation/config/ -> /api/uci/
        execute(
            ssh, "sed -i 's/\\/api\\/basicstation\\/config/\\/api\\/uci/g' /tmp/p.js"
        )

        execute(ssh, f"gzip -c /tmp/p.js > {f}")

        # Verify
        check, _ = execute(ssh, f"zcat {f} | grep -a -o '/api/uci' | head -n 1")
        print(f"  Verified: {check}")

    print("\n--- 3. Final configuration ---")
    if STATION_ID:
        execute(ssh, f"uci set basicstation.station.stationid='{STATION_ID}'")
    if LNS_TOKEN:
        execute(ssh, f"uci set basicstation.auth.token='{LNS_TOKEN}'")
    execute(ssh, "uci commit basicstation")
    execute(ssh, "/etc/init.d/basicstation restart")
    print("Configuration applied and station restarted.")

    ssh.close()
except Exception as e:
    print(f"Error: {e}")
