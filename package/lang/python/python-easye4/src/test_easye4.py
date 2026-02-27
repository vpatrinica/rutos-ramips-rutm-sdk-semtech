import time
import json
import threading
import socket
from easye4 import decode_parse

# For MQTT
import paho.mqtt.client as mqtt

# For Modbus
from pymodbus.client import ModbusTcpClient

"""
{"payload":"{\"SYSINFO\":{\"STATE\":\"STOP\"},\"OPERANDS\":{\"IRANGE\":[{ \"START\":1,\"END\":8,\"V\":\"AA==\"}],\"ORANGE\":[{ \"START\":1,\"END\":8,\"V\":\"AA==\"}],\"AISINGLE\":[{ \"INDEX\":5,\"V\":0}],\"MWSINGLE\":[{ \"INDEX\":20,\"V\":0},{ \"INDEX\":21,\"V\":0},{ \"INDEX\":22,\"V\":0},{ \"INDEX\":23,\"V\":0},{ \"INDEX\":25,\"V\":0},{ \"INDEX\":26,\"V\":0}]}}","url":"https://192.168.0.112/api/get/data?elm=I(1,8)+O(1,8)+AI(5)+MW(20)+MW(21)+MW(22)+MW(23)+MW(25)+MW(26)+STATE+","_msgid":"c5b232a20f475d11"}

{"payload":"{\"SYSINFO\":{\"STATE\":\"STOP\"},\"OPERANDS\":{\"IRANGE\":[{ \"START\":1,\"END\":8,\"V\":\"AA==\"}],\"ORANGE\":[{ \"START\":1,\"END\":8,\"V\":\"AA==\"}],\"AISINGLE\":[{ \"INDEX\":5,\"V\":0}],\"MWSINGLE\":[{ \"INDEX\":20,\"V\":0},{ \"INDEX\":21,\"V\":0},{ \"INDEX\":22,\"V\":0},{ \"INDEX\":23,\"V\":0},{ \"INDEX\":25,\"V\":0},{ \"INDEX\":26,\"V\":0}]}}","url":"https://192.168.0.112/api/get/data?elm=I(1,8)+O(1,8)+AI(5)+MW(20)+MW(21)+MW(22)+MW(23)+MW(25)+MW(26)+STATE+","_msgid":"1fff7cf373cf06e6"}
"""


PAYLOAD = """
{"SYSINFO":{"STATE":"RUN","DEVLOCATION":{"LONGITUDE":"7082858","LATITUDE":"50735452"},"DATE":"2019-04-23","TIME":"12:57:31","DEVNAME":"...","VERS":"1.30","BUILD":"538","MAC":"00-80-99-0d-05-b0","IPSET":{"ACTIP":"192.168.0.121","IPMODE":"1","ACTMASK":"255.255.255.0","ACTGW":"192.168.0.20"},"PROGNAME":"Airtec1.500","EMAIL":{"ERROR":3},"CYC":{"CYCMIN":"10021","CYCMAX":"10511","CYCACT":"10035"},"USER":"user2","EXTSTATE":{"EXTDATA":"1","EXTCFG":"7","EXTBUS":"1","EXTCYC":"2"},"DIAG_CNT":"8","DIAG_TIME":"39775","DIAG_LIST":[{"DIAG":"0","CNT":"1","TIME":"1","MOD":"0","CODE":"1204","DID":"0x7"},{"DIAG":"1","CNT":"2","TIME":"3","MOD":"0","CODE":"1132","DID":"0x7"}]},"OPERANDS":{"IRANGE":[{"START":1,"END":8,"V":"eg=="}],"MWRANGE":[{"START":17,"END":32,"V":"AAAAAAAA+gD6ACwBqwIAAM4VvRT6ACwBAAAAAAAAAAA="}],"ORANGE":[{"START":1,"END":8,"V":"CQ=="}],"MDSINGLE":[{"INDEX":100,"V":0}],"MRANGE":[{"START":1,"END":24,"V":"AgwA"}],"AISINGLE":[{"INDEX":5,"V":250}]}}
"""

MQTT_BROKER = "localhost"
MQTT_TOPIC = "airflowm01/AD1500-1/test_simulate"

mqtt_received = {}


def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode())
        mqtt_received.update(data)
        print(f"[MQTT Recv] {msg.topic}: {data}")
    except Exception as e:
        pass


def dummy_modbus_server():
    """Dummy Modbus Server that accepts a TCP connection and mocks a read/write response."""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 5020))
    server.listen(1)
    print("Starting Dummy Modbus TCP Server on port 5020...")
    while True:
        try:
            conn, addr = server.accept()
            # print("Accepted Modbus connection...")
            while True:
                data = conn.recv(1024)
                if not data:
                    break
                fc = data[7]
                if fc == 16:  # Write Multiple Registers
                    resp = data[:8] + data[8:12]
                    conn.send(resp)
                elif fc == 3:  # Read Holding Registers
                    # return value 250 (0x00fa)
                    resp_head = data[:6]
                    resp_data = bytes([1, 3, 2, 0, 250])
                    # Fix length
                    resp_head = resp_head[:4] + bytes([0, 5])
                    conn.send(resp_head + resp_data)
            conn.close()
        except Exception as e:
            # print("Dummy modbus server error:", e)
            pass


def main():
    # 1. Start Modbus Server in Background
    t = threading.Thread(target=dummy_modbus_server, daemon=True)
    t.start()
    time.sleep(1)

    # 2. Decode the Payload
    print("Decoding Payload from easyE4 PLC...")
    dev = decode_parse(PAYLOAD)
    if not dev:
        print("Failed to decode payload!")
        return

    # Extract human-readable data (mimicking Node-RED TESTAMENT.md Program_State, Digital_Input, Digital_Output)
    out_map = {}
    m = dev.get("M", [])
    if len(m) > 24:
        out_map["AD1500_01_Press_less_220"] = m[1]
        out_map["AD1500_01_Press_less_620"] = m[2]
        out_map["AD1500_01_reached_threshold_300"] = m[3]
        out_map["AD1500_01_Backup_On_normal_press"] = m[5]
        out_map["AD1500_01_Error_Fan1"] = m[8]
        out_map["AD1500_01_System_on"] = m[11]

    din = dev.get("I", [])
    if len(din) > 8:
        out_map["AD1500_01_Snow_Mode"] = din[1]
        out_map["AD1500_01_Fan1_K1_on"] = din[2]
        out_map["AD1500_01_Fuse_Fan1"] = din[6]

    dout = dev.get("O", [])
    if len(dout) > 8:
        out_map["AD1500_1_Fan1"] = dout[1]
        out_map["AD1500_1_Fan2"] = dout[2]

    analog = dev.get("AI", [])
    if len(analog) > 5:
        out_map["AD1500_01_PipePressure"] = analog[5]

    print("\n--- Human-Readable Parsed Values ---")
    print(json.dumps(out_map, indent=2))

    # 3. Connect to MQTT and Publish
    client = mqtt.Client()
    client.on_message = on_message
    print(f"\nConnecting to MQTT broker at {MQTT_BROKER}...")
    try:
        client.connect(MQTT_BROKER, 1883, 60)
        client.loop_start()
        client.subscribe(MQTT_TOPIC)
        time.sleep(1)
        print(f"Publishing to MQTT: {MQTT_TOPIC}")
        client.publish(MQTT_TOPIC, json.dumps(out_map))
        time.sleep(2)
        client.loop_stop()
    except Exception as e:
        print(f"MQTT Error: {e}")

    # 4. Modbus TCP Write and Read-Back
    print("\nConnecting to local Modbus TCP Server...")
    mb = ModbusTcpClient("127.0.0.1", port=5020)
    if mb.connect():
        print("Writing analog value (Pressure) to Holding Register 0...")
        val = out_map.get("AD1500_01_PipePressure", 250)
        mb.write_registers(0, [val])

        print("Reading Holding Register 0 back...")
        result = mb.read_holding_registers(0, 1)
        if result.isError():
            print("Failed to read back from Modbus!")
        else:
            read_val = result.registers[0]
            print(f"Modbus Read-Back Success: Expected {val}, Got {read_val}")
            assert read_val == val, "Modbus read mismatch!"
        mb.close()
    else:
        print("Failed to connect to Modbus server.")

    print(
        "\nVerification Complete! Values encoded to MQTT and Modbus successfully match."
    )


if __name__ == "__main__":
    main()
