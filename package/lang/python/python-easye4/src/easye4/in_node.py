import base64
import logging
import ssl
import urllib.request
from .decoder import decode_parse


logger = logging.getLogger(__name__)


def get_legacy_ssl_context():
    """Adapter to bypass strict OpenSSL requirements when connecting to PLCs."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    # OP_LEGACY_SERVER_CONNECT is 0x4, OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION is 0x40000
    try:
        ctx.set_ciphers("DEFAULT@SECLEVEL=0")
        ctx.options |= getattr(ssl, "OP_LEGACY_SERVER_CONNECT", 0x4)
        ctx.options |= 0x40000
    except Exception:
        pass  # Ignore if options not supported by underlying OpenSSL
    return ctx


class EasyE4In:
    """Mimics the Node-RED easyE4 IN node."""

    def __init__(self, name, com_node, sysinfo=None, operands_list=None):
        self.name = name
        self.com = com_node
        self.sysinfo = sysinfo or []
        self.operands_list = operands_list or []
        self.ssl_ctx = get_legacy_ssl_context()

    def fetch(self, raw_json=None):
        """
        Fetches the device status and decodes it.
        If raw_json is provided as string, returns decoded simulation.
        """
        if raw_json is not None:
            return decode_parse(raw_json)

        # Real HTTP behavior (simplified for test, normally would construct ?elm=... query)
        url = f"{self.com.protocol}://{self.com.ip}/api/get/data?elm=STATE+DEVLOCATION+DATE+TIME"
        logger.debug(
            f"\\n\\nDEBUG: URL={url}, AUTH={self.com.base_auth_user}:***\\n\\n"
        )
        req = urllib.request.Request(url)
        req.add_header("Content-Type", "application/json")
        req.add_header("Connection", "keep-alive")

        if self.com.auth_scheme == "Basic":
            auth_str = f"{self.com.base_auth_user}:{self.com.base_auth_pass}"
            b64_auth = base64.b64encode(auth_str.encode()).decode()
            req.add_header("Authorization", f"Basic {b64_auth}")

        # Adding an empty User-Agent is required to prevent the PLC from blocking standard library signatures.
        # It MUST be the very last header added, as the PLC's string parser crashes if another header follows an empty value.
        req.add_header("User-Agent", "")

        try:
            with urllib.request.urlopen(req, context=self.ssl_ctx, timeout=3) as res:
                body = res.read().decode("utf-8")
                return decode_parse(body)
        except Exception as e:
            print(f"Error fetching from easyE4: {e}")
            return None
