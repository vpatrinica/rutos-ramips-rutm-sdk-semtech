#!/bin/sh

[ "$SUBSYSTEM" = "tty" ] || exit 0

case "$ACTION" in
    add)
        if [ -h "/dev/usb_serial_48c8add9" ] && [ "$(readlink /dev/usb_serial_48c8add9)" = "/dev/$DEVICENAME" ]; then
            ln -sf "/dev/$DEVICENAME" /dev/modbus
            logger -t modbus-alias "Created /dev/modbus -> /dev/$DEVICENAME"
        fi
        ;;
    remove)
        if [ -h "/dev/modbus" ] && [ "$(readlink /dev/modbus)" = "/dev/$DEVICENAME" ]; then
            rm -f /dev/modbus
            logger -t modbus-alias "Removed /dev/modbus"
        fi
        ;;
esac
