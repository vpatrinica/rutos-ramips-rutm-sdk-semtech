import json
import logging
from typing import Any, Dict, Optional

import paho.mqtt.client as mqtt

logger = logging.getLogger(__name__)


class MqttPublisher:
    def __init__(
        self,
        broker_host: str,
        broker_port: int = 1883,
        topic: str = "easye4/data",
        client_id: str = "easye4_client",
        username: Optional[str] = None,
        password: Optional[str] = None,
    ):
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.topic = topic
        self.client_id = client_id

        self.client = mqtt.Client(client_id=client_id)
        if username:
            self.client.username_pw_set(username, password)

        self.connected = False

    def connect(self) -> None:
        try:
            self.client.connect(self.broker_host, self.broker_port, keepalive=60)
            self.client.loop_start()
            self.connected = True
            logger.info(
                f"Connected to MQTT broker at {self.broker_host}:{self.broker_port}"
            )
        except Exception as e:
            logger.error(f"Failed to connect to MQTT broker: {e}")
            self.connected = False

    def publish(self, data: Dict[str, Any], subtopic: str = "") -> None:
        if not self.connected:
            self.connect()

        if not self.connected:
            logger.warning("Not dropping data, but MQTT is disconnected.")
            return

        final_topic = f"{self.topic}/{subtopic}" if subtopic else self.topic
        try:
            payload = json.dumps(data)
            self.client.publish(final_topic, payload, qos=0)
            logger.debug(f"Published to {final_topic}")
        except Exception as e:
            logger.error(f"Failed to publish to MQTT: {e}")

    def disconnect(self) -> None:
        if self.connected:
            self.client.loop_stop()
            self.client.disconnect()
            self.connected = False
            logger.info("Disconnected from MQTT broker")
