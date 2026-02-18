#!/usr/bin/env python3
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "util"))
from env_config import DEVICE_IP, DEVICE_PASS, DEVICE_USER

import paramiko

host = DEVICE_IP
user = DEVICE_USER
password = DEVICE_PASS

commands = [
    ("UCI CONFIG", "uci show basicstation 2>&1"),
    ("SERVICE STATUS", "/etc/init.d/basicstation status 2>&1; echo EXIT=$?"),
    ("PROCESS CHECK", "ps w | grep -i station 2>&1"),
    ("LOG FILE", "ls -la /tmp/basicstation/ 2>&1; head -20 /tmp/basicstation/log 2>&1"),
    (
        "API LUA FILE LOCATION",
        "find / -path '*/api/*basicstation*' -type f 2>/dev/null",
    ),
    ("API PATH.D", "cat /usr/share/vuci/path.d/*basicstation* 2>&1"),
    (
        "ACL FILES",
        "ls -la /usr/share/rpcd/acl.d/*basicstation* 2>&1; cat /usr/share/rpcd/acl.d/*basicstation* 2>&1",
    ),
    ("VUCI ACL", "cat /usr/share/vuci/acl.d/*basicstation* 2>&1"),
    ("MENU", "cat /usr/share/vuci/menu.d/*basicstation* 2>&1"),
    ("RPCD STATUS", "ps | grep rpcd 2>&1"),
    ("BASICSERVICE FILE", "ls -la /usr/lib/lua/api/BasicService.lua 2>&1"),
    ("SYSLOG BASICSTATION", "logread | grep -i basicstation | tail -30 2>&1"),
    ("SYSLOG VUCI", "logread | grep -i vuci | tail -20 2>&1"),
    ("VUCI INSTALLED PACKAGES", "opkg list-installed | grep -i basicstation 2>&1"),
    ("LUA PATH", "lua -e 'print(package.path)' 2>&1"),
]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    client.connect(
        host,
        username=user,
        password=password,
        timeout=15,
        allow_agent=False,
        look_for_keys=False,
        disabled_algorithms=dict(pubkeys=["rsa-sha2-512", "rsa-sha2-256"]),
    )
    for label, cmd in commands:
        print(f"\n{'=' * 60}")
        print(f"=== {label} ===")
        print(f"{'=' * 60}")
        stdin, stdout, stderr = client.exec_command(cmd, timeout=10)
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        if out.strip():
            print(out.strip())
        if err.strip():
            print(f"STDERR: {err.strip()}")
except Exception as e:
    print(f"FAILED: {e}")
finally:
    client.close()
