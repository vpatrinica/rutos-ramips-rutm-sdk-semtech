#!/usr/bin/env python3
import os
import sys

def patch_config():
    # Load from .env or environment
    station_id = os.environ.get('STATION_ID')
    lns_token = os.environ.get('LNS_TOKEN')

    if not station_id or not lns_token:
        # Try to read from .env file directly if not in environment
        try:
            with open('.env', 'r') as f:
                for line in f:
                    if line.startswith('STATION_ID='):
                        station_id = line.split('=', 1)[1].strip()
                    if line.startswith('LNS_TOKEN='):
                        lns_token = line.split('=', 1)[1].strip()
        except FileNotFoundError:
            pass

    if not station_id or not lns_token:
        print("Error: STATION_ID and LNS_TOKEN must be set in .env or environment")
        sys.exit(1)

    config_path = 'package/feeds/packages/lora-basicstation/files/etc/config/basicstation'
    
    with open(config_path, 'r') as f:
        content = f.read()

    # Apply patches
    # 1. Patch Token
    # The original file has: option token 'Authorization: Bearer NNSXS.'
    # We want: option token 'NNSXS.W6DIA...'
    import re
    content = re.sub(r"option token 'Authorization: Bearer NNSXS\.'", f"option token '{lns_token}'", content)
    
    # 2. Patch Station ID
    # The original file has: option stationid '00:00:00:00:00:00:00:00'
    content = re.sub(r"option stationid '00:00:00:00:00:00:00:00'", f"option stationid '{station_id}'", content)
    
    # 3. Patch Cert Paths (as previously seen)
    content = content.replace("option trust '/etc/config/tc.trust'", "option trust '/etc/basicstation/tc.trust'")
    content = content.replace("option key ''", "option key '/etc/basicstation/tc.key'")
    content = content.replace("option crt ''", "option crt '/etc/basicstation/tc.crt'")

    with open(config_path, 'w') as f:
        f.write(content)
    
    print(f"Patched {config_path} with Station ID: {station_id}")

if __name__ == "__main__":
    patch_config()
