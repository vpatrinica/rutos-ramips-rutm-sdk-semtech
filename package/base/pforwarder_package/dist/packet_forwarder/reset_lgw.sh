#!/bin/sh

# This script is intended to be used on SX1302 CoreCell platform, it performs
# the following actions:
# Toggles reset LORA concentrator GPIO Bank 3, Pin 17

exit 0
init() {
    gpioset 3 17=1
	sleep 0.5
	gpioset 3 17=0
}

case "$1" in
    start)
	init
    ;;
    stop)
	init
    ;;
    *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac

exit 0
