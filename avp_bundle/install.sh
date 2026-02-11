#!/bin/sh

# Installation script for AVP packages on the target device
# This script should be run from within the bundle directory

echo "Starting AVP Python and BasicStation package installation..."

# 1. Base Python
echo "Installing base Python..."
opkg install python3-base_*.ipk python3-light_*.ipk python3-logging_*.ipk python3-email_*.ipk python3-urllib_*.ipk python3-openssl_*.ipk python3-ctypes_*.ipk python3-multiprocessing_*.ipk python3-decimal_*.ipk python3-asyncio_*.ipk python3-uuid_*.ipk python3-xml_*.ipk python3-codecs_*.ipk

# 2. System dependencies and core modules
echo "Installing system dependencies and core modules..."
opkg install libsodium_*.ipk python3-six_*.ipk python3-ply_*.ipk python3-pycparser_*.ipk

# 3. CFFI and Cryptography (Rust-free)
echo "Installing CFFI and Cryptography..."
opkg install python3-cffi_*.ipk
opkg install python3-cryptography_*.ipk

# 4. Security modules
echo "Installing security modules..."
opkg install python3-bcrypt_*.ipk python3-pyopenssl_*.ipk

# 5. Networking and Protocol modules
echo "Installing networking and protocol modules..."
opkg install python3-idna_*.ipk python3-chardet_*.ipk python3-certifi_*.ipk python3-urllib3_*.ipk
opkg install python3-requests_*.ipk
opkg install python3-paramiko_*.ipk

# 6. Additional requested modules
echo "Installing additional modules..."
opkg install python3-pyserial_*.ipk python3-ubus_*.ipk python3-uci_*.ipk python3-pymodbus_*.ipk python3-pahomqtt_*.ipk

# 7. BasicStation and LoRa components
#echo "Installing BasicStation and LoRa components..."
#opkg install libmbedtls21_*.ipk
#opkg install sx1302_hal-utils_*.ipk
#opkg install lora-basicstation_*.ipk
#opkg install vuci-app-basicstation-api_*.ipk
#opkg install vuci-app-basicstation-ui_*.ipk

echo "Installation complete!"
