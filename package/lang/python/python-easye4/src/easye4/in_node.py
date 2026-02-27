import base64
import requests
import json
from .decoder import decode_parse


class EasyE4In:
    """Mimics the Node-RED easyE4 IN node."""

    def __init__(self, name, com_node, sysinfo=None, operands_list=None):
        self.name = name
        self.com = com_node
        self.sysinfo = sysinfo or []
        self.operands_list = operands_list or []

    def fetch(self, raw_json=None):
        """
        Fetches the device status and decodes it.
        If raw_json is provided as string, returns decoded simulation.
        """
        if raw_json is not None:
            return decode_parse(raw_json)

        # Real HTTP behavior (simplified for test, normally would construct ?elm=... query)
        url = f"{self.com.protocol}://{self.com.ip}/api/get/data?elm=STATE+DEVLOCATION+DATE+TIME"
        headers = {"Content-Type": "application/json"}
        if self.com.auth_scheme == "Basic":
            auth_str = f"{self.com.base_auth_user}:{self.com.base_auth_pass}"
            b64_auth = base64.b64encode(auth_str.encode()).decode()
            headers["Authorization"] = f"Basic {b64_auth}"

        try:
            res = requests.get(url, headers=headers, timeout=3)
            res.raise_for_status()
            return decode_parse(res.text)
        except Exception as e:
            print(f"Error fetching from easyE4: {e}")
            return None
