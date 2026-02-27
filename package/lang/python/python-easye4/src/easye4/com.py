class EasyE4Com:
    """Mimics the Node-RED easyE4 COM node."""

    def __init__(
        self,
        device_id,
        ip,
        auth_scheme="Basic",
        protocol="http",
        base_auth_user="",
        base_auth_pass="",
        cycle_time=15000,
    ):
        if int(cycle_time) < 500:
            raise ValueError("minimum cycle time is 500ms")
        self.device_id = device_id
        self.ip = ip
        self.auth_scheme = auth_scheme
        self.protocol = protocol
        self.base_auth_user = base_auth_user
        self.base_auth_pass = base_auth_pass
        self.cycle_time = int(cycle_time)
        self.connected = True
