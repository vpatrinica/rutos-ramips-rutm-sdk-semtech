# mypy: ignore-errors
import logging
import threading
from typing import Dict, Any

try:
    from pymodbus.server import StartTcpServer, StartSerialServer
    from pymodbus.datastore import ModbusSequentialDataBlock
    from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext
except ImportError:
    pass

logger = logging.getLogger(__name__)


class ModbusPublisher:
    def __init__(
        self,
        mode: str = "tcp",
        host: str = "0.0.0.0",
        port: int = 5020,
        serial_port: str = "/dev/ttyUSB0",
        baudrate: int = 9600,
        slave_id: int = 1,
    ):
        self.mode = mode
        self.host = host
        self.port = port
        self.serial_port = serial_port
        self.baudrate = baudrate
        self.slave_id = slave_id

        # Initialize an empty datastore with 1000 registers
        self.store = ModbusSlaveContext(
            di=ModbusSequentialDataBlock(0, [0] * 1000),
            co=ModbusSequentialDataBlock(0, [0] * 1000),
            hr=ModbusSequentialDataBlock(0, [0] * 1000),
            ir=ModbusSequentialDataBlock(0, [0] * 1000),
        )
        self.context = ModbusServerContext(slaves={slave_id: self.store}, single=False)
        self.server_thread = None

    def start(self):
        """Starts the Modbus TCP server in a background thread."""
        if self.mode == "tcp":
            logger.info(f"Starting Modbus TCP server on {self.host}:{self.port}")
        elif self.mode == "rtu":
            logger.info(
                f"Starting Modbus RTU server on {self.serial_port} ({self.baudrate} baud)"
            )
        self.server_thread = threading.Thread(target=self._run_server, daemon=True)
        self.server_thread.start()

    def _run_server(self):
        if self.mode == "tcp":
            StartTcpServer(context=self.context, address=(self.host, self.port))
        elif self.mode == "rtu":
            StartSerialServer(
                context=self.context,
                port=self.serial_port,
                framer="rtu",
                baudrate=self.baudrate,
            )

    def update_from_dev(self, dev: Dict[str, Any]):
        """
        Maps EasyE4 dev object to Modbus registers.
        Inputs (I) config mapped to Discrete Inputs (di)
        Outputs (O) mapped to Coils (co)
        Marker Words (MW) mapped to Holding Registers (hr)
        Analog Inputs (AI) mapped to Input Registers (ir)
        """
        if not self.context:
            return

        # Update I -> di (Offset 0)
        i_array = dev.get("I", [])
        for idx in range(1, len(i_array)):
            if i_array[idx] is not None:
                self.store.setValues(
                    2, idx, [int(i_array[idx])]
                )  # di is usually func code 2

        # Update O -> co (Offset 0)
        o_array = dev.get("O", [])
        for idx in range(1, len(o_array)):
            if o_array[idx] is not None:
                self.store.setValues(1, idx, [int(o_array[idx])])  # co is func code 1

        # Update MW -> hr (Offset 0)
        mw_array = dev.get("MW", [])
        for idx in range(1, len(mw_array)):
            if mw_array[idx] is not None:
                self.store.setValues(3, idx, [int(mw_array[idx])])  # hr is func code 3

        # Update AI -> ir (Offset 0)
        ai_array = dev.get("AI", [])
        for idx in range(1, len(ai_array)):
            if ai_array[idx] is not None:
                self.store.setValues(4, idx, [int(ai_array[idx])])  # ir is func code 4
