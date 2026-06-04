#!/bin/bash
# USB RNDIS gadget setup for OnePlus 11 (salami) on Droidian
#
# Creates a single RNDIS (USB Ethernet) function on the SM8550 DWC3
# controller so the device appears as a USB network adapter on the host.
# After boot: ssh droidian@192.168.2.15 (password: 1234 on stock Droidian)
#
# USB controller: a600000.dwc3  (confirmed in vendor.prop)
# Run by: usb-rndis.service (after sys-kernel-config.mount)

set -e

GADGET=/sys/kernel/config/usb_gadget/g1
UDC=a600000.dwc3

# Bail out if gadget already bound
[ -f "$GADGET/UDC" ] && [ -n "$(cat $GADGET/UDC)" ] && exit 0

mkdir -p "$GADGET"

# ---- USB device descriptor ------------------------------------------------
echo 0x2A70 > "$GADGET/idVendor"      # OnePlus
echo 0x4EE7 > "$GADGET/idProduct"     # Halium debug RNDIS
echo 0x0300 > "$GADGET/bcdDevice"
echo 0x0200 > "$GADGET/bcdUSB"

mkdir -p "$GADGET/strings/0x409"
echo "OnePlus"                  > "$GADGET/strings/0x409/manufacturer"
echo "OnePlus 11 (Droidian)"    > "$GADGET/strings/0x409/product"
# Serial number: read from /proc/cmdline androidboot.serialno if present,
# fall back to a static string so the gadget always comes up.
SERIAL=$(grep -oP 'androidboot\.serialno=\K\S+' /proc/cmdline 2>/dev/null || echo "salami000000")
echo "$SERIAL" > "$GADGET/strings/0x409/serialnumber"

# ---- RNDIS function --------------------------------------------------------
mkdir -p "$GADGET/functions/rndis.usb0"
# RNDIS class/subclass/protocol per USB CDC spec
echo 0xEF > "$GADGET/functions/rndis.usb0/class"
echo 0x04 > "$GADGET/functions/rndis.usb0/subclass"
echo 0x01 > "$GADGET/functions/rndis.usb0/protocol"

# ---- Configuration ---------------------------------------------------------
mkdir -p "$GADGET/configs/c.1/strings/0x409"
echo "RNDIS"   > "$GADGET/configs/c.1/strings/0x409/configuration"
echo 500       > "$GADGET/configs/c.1/MaxPower"
echo 0x80      > "$GADGET/configs/c.1/bmAttributes"  # bus-powered

# Link RNDIS function into the configuration
ln -sf "$GADGET/functions/rndis.usb0" "$GADGET/configs/c.1/"

# ---- Bind to UDC -----------------------------------------------------------
echo "$UDC" > "$GADGET/UDC"

echo "USB RNDIS gadget active on $UDC"
