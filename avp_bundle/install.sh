#!/bin/sh

# BasicStation and LoRa components
echo "Installing BasicStation and LoRa components..."
opkg remove --force-depends lora-basicstation
opkg remove --force-depends vuci-app-basicstation-api
opkg remove --force-depends vuci-app-basicstation-ui
opkg remove --force-depends sx1302_hal-utils
opkg remove --force-depends libmbedtls21

opkg install libmbedtls21_*.ipk
opkg install sx1302_hal-utils_*.ipk
opkg install lora-basicstation_*.ipk
opkg install vuci-app-basicstation-api_*.ipk
opkg install vuci-app-basicstation-ui_*.ipk

echo "Installation complete!"
