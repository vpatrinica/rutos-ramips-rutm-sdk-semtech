import argparse
import logging
import time

from easye4.com import EasyE4Com
from easye4.in_node import EasyE4In
from easye4.publishers import MqttPublisher
from easye4.modbus_server import ModbusPublisher

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("easye4_service")


def main():
    parser = argparse.ArgumentParser(description="Eaton EasyE4 Polling Service")
    parser.add_argument("--ip", required=True, help="IP address of the EasyE4 node")
    parser.add_argument("--device_id", default="easyE4", help="Device ID")
    parser.add_argument(
        "--auth_scheme", default="Basic", help="Authentication scheme (Basic, None)"
    )
    parser.add_argument("--auth_user", default="", help="Authentication username")
    parser.add_argument("--auth_pass", default="", help="Authentication password")
    parser.add_argument(
        "--interval", type=int, default=15000, help="Polling interval in milliseconds"
    )
    parser.add_argument(
        "--use_https", action="store_true", help="Use HTTPS instead of HTTP"
    )

    # MQTT arguments
    parser.add_argument("--mqtt_broker", help="MQTT broker host")
    parser.add_argument("--mqtt_port", type=int, default=1883, help="MQTT broker port")
    parser.add_argument("--mqtt_topic", default="easye4/data", help="MQTT base topic")
    parser.add_argument("--mqtt_user", default="", help="MQTT username")
    parser.add_argument("--mqtt_pass", default="", help="MQTT password")

    # Modbus arguments
    parser.add_argument(
        "--modbus_mode",
        choices=["tcp", "rtu", "none"],
        default="none",
        help="Modbus server mode",
    )
    parser.add_argument("--modbus_host", default="0.0.0.0", help="Modbus TCP host")
    parser.add_argument("--modbus_port", type=int, default=5020, help="Modbus TCP port")
    parser.add_argument(
        "--modbus_serial", default="/dev/ttyUSB0", help="Modbus RTU serial port"
    )
    parser.add_argument(
        "--modbus_baud", type=int, default=9600, help="Modbus RTU baud rate"
    )
    parser.add_argument(
        "--modbus_slave_id", type=int, default=1, help="Modbus slave ID"
    )

    args = parser.parse_args()

    # Ensure interval is at least 500ms
    interval_s = max(500, args.interval) / 1000.0

    proto = "HTTPS" if args.use_https else "HTTP"
    logger.info(f"Initializing EasyE4 connection to {args.ip} via {proto}")
    com_node = EasyE4Com(
        device_id=args.device_id,
        ip=args.ip,
        auth_scheme=args.auth_scheme,
        protocol="https" if args.use_https else "http",
        base_auth_user=args.auth_user,
        base_auth_pass=args.auth_pass,
        cycle_time=max(500, args.interval),
    )
    in_node = EasyE4In("poller", com_node)

    mqtt_pub = None
    if args.mqtt_broker:
        logger.info(f"Setting up MQTT publisher to {args.mqtt_broker}:{args.mqtt_port}")
        mqtt_pub = MqttPublisher(
            broker_host=args.mqtt_broker,
            broker_port=args.mqtt_port,
            topic=args.mqtt_topic,
            username=args.mqtt_user if args.mqtt_user else None,
            password=args.mqtt_pass if args.mqtt_pass else None,
        )
        mqtt_pub.connect()

    modbus_pub = None
    if args.modbus_mode != "none":
        logger.info(f"Setting up Modbus {args.modbus_mode.upper()} server")
        modbus_pub = ModbusPublisher(
            mode=args.modbus_mode,
            host=args.modbus_host,
            port=args.modbus_port,
            serial_port=args.modbus_serial,
            baudrate=args.modbus_baud,
            slave_id=args.modbus_slave_id,
        )
        modbus_pub.start()

    logger.info(f"Starting polling loop. Interval: {interval_s}s")
    try:
        while True:
            start_time = time.time()
            data = in_node.fetch()

            if data:
                # Need to iterate through devices if the response contains multiple, but decode_parse
                # typically returns a single device dict according to standard Node-RED structure,
                # or perhaps {"DEV01": {...}} depending on decode output. Let's assume it returns
                # the decoded object directly or {"deviceId": data}.
                # The decoder.py parse outputs: return obj["DEVICE"][0] normally. Let's send the whole data.

                # Publish to MQTT
                if mqtt_pub:
                    mqtt_pub.publish(data)

                # Update Modbus
                if modbus_pub:
                    # In decoder.py, it returns decoded `dev` object e.g., {'I': [...], 'O': [...], ...}
                    modbus_pub.update_from_dev(data)

            else:
                logger.warning("Failed to fetch data from EasyE4 node")

            # Sleep for the remainder of the interval
            elapsed = time.time() - start_time
            sleep_time = interval_s - elapsed
            if sleep_time > 0:
                time.sleep(sleep_time)

    except KeyboardInterrupt:
        logger.info("Service stopping due to KeyboardInterrupt")
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
    finally:
        if mqtt_pub:
            mqtt_pub.disconnect()
        logger.info("Service stopped")


if __name__ == "__main__":
    main()
