#!/bin/bash
# halium-install post-install hook for OnePlus 11 (salami)
#
# Called by halium-install with the mounted Droidian rootfs path as $1.
# Copies every device-specific config from /system/etc/halium/ to its
# correct destination inside the rootfs, then enables systemd services.
#
# Usage (called automatically by halium-install, or manually):
#   halium-install-salami.sh /mnt/droidian-rootfs

set -euo pipefail

ROOTFS="${1:-/}"
SRC="/system/etc/halium"

log() { echo "[salami] $*"; }

# ---------------------------------------------------------------------------
# LXC Android container
# ---------------------------------------------------------------------------
log "Installing LXC Android container config"
install -Dm644 "$SRC/lxc-android.conf" \
    "$ROOTFS/var/lib/lxc/android/config"

# ---------------------------------------------------------------------------
# halium.prop
# ---------------------------------------------------------------------------
log "Installing halium.prop"
install -Dm644 "$SRC/halium.prop" \
    "$ROOTFS/etc/halium.prop"

# ---------------------------------------------------------------------------
# udev rules
# ---------------------------------------------------------------------------
log "Installing udev rules"
install -Dm644 "$SRC/70-salami.rules" \
    "$ROOTFS/lib/udev/rules.d/70-salami.rules"

# ---------------------------------------------------------------------------
# fixup-mountpoints
# ---------------------------------------------------------------------------
log "Installing fixup-mountpoints"
install -Dm755 "$SRC/fixup-mountpoints" \
    "$ROOTFS/usr/local/sbin/fixup-mountpoints"

# ---------------------------------------------------------------------------
# ofono
# ---------------------------------------------------------------------------
log "Installing ofono config"
mkdir -p "$ROOTFS/etc/ofono"
install -Dm644 "$SRC/ril_subscription.conf" "$ROOTFS/etc/ofono/ril_subscription.conf"
install -Dm644 "$SRC/phonesim.conf"         "$ROOTFS/etc/ofono/phonesim.conf"
install -Dm644 "$SRC/ofono.conf"            "$ROOTFS/etc/ofono/ofono.conf"

# ---------------------------------------------------------------------------
# NetworkManager
# ---------------------------------------------------------------------------
log "Installing NetworkManager config"
mkdir -p "$ROOTFS/etc/NetworkManager/conf.d"
install -Dm644 "$SRC/10-ofono.conf"         "$ROOTFS/etc/NetworkManager/conf.d/10-ofono.conf"
install -Dm644 "$SRC/20-connectivity.conf"  "$ROOTFS/etc/NetworkManager/conf.d/20-connectivity.conf"

# ---------------------------------------------------------------------------
# Phoc (Wayland compositor)
# ---------------------------------------------------------------------------
log "Installing phoc.ini"
install -Dm644 "$SRC/phoc.ini" "$ROOTFS/etc/phoc.ini"

# ---------------------------------------------------------------------------
# PulseAudio hybris audio
# ---------------------------------------------------------------------------
log "Installing PulseAudio droid config"
install -Dm644 "$SRC/pulse-droid.pa" "$ROOTFS/etc/pulse/droid.pa"

# Append include into default.pa if not already there
DEFAULT_PA="$ROOTFS/etc/pulse/default.pa"
if [ -f "$DEFAULT_PA" ] && ! grep -q 'droid.pa' "$DEFAULT_PA"; then
    echo '' >> "$DEFAULT_PA"
    echo '.include /etc/pulse/droid.pa' >> "$DEFAULT_PA"
    log "Appended droid.pa include to default.pa"
fi

# ---------------------------------------------------------------------------
# Bluetooth
# ---------------------------------------------------------------------------
log "Installing BlueZ config"
install -Dm644 "$SRC/bluetooth-main.conf" \
    "$ROOTFS/etc/bluetooth/main.conf"

# ---------------------------------------------------------------------------
# AppArmor profile for the Android LXC container
# ---------------------------------------------------------------------------
log "Installing AppArmor LXC profile"
mkdir -p "$ROOTFS/etc/apparmor.d/lxc"
install -Dm644 "$SRC/lxc-android-apparmor" \
    "$ROOTFS/etc/apparmor.d/lxc/lxc-android"

# ---------------------------------------------------------------------------
# fprintd (under-display fingerprint)
# ---------------------------------------------------------------------------
log "Installing fprintd-droid config"
mkdir -p "$ROOTFS/etc/fprintd"
install -Dm644 "$SRC/fprintd-droid.conf" \
    "$ROOTFS/etc/fprintd/fprintd.conf"

# ---------------------------------------------------------------------------
# dconf display overrides (Phosh)
# ---------------------------------------------------------------------------
log "Installing dconf overrides"
mkdir -p "$ROOTFS/etc/dconf/db/vendor.d"
install -Dm644 "$SRC/dconf-droidian.ini" \
    "$ROOTFS/etc/dconf/db/vendor.d/10-droidian.ini"

# Ensure the vendor dconf profile exists
PROFILE="$ROOTFS/etc/dconf/profile/user"
mkdir -p "$(dirname $PROFILE)"
if ! grep -q 'vendor' "$PROFILE" 2>/dev/null; then
    printf 'user-db:user\nsystem-db:vendor\n' > "$PROFILE"
fi

# Compile the dconf database inside the rootfs
chroot "$ROOTFS" dconf update 2>/dev/null || log "dconf update skipped (not critical)"

# ---------------------------------------------------------------------------
# USB RNDIS gadget systemd service
# ---------------------------------------------------------------------------
log "Installing USB RNDIS gadget service"
install -Dm755 "$SRC/usb-rndis.sh"      "$ROOTFS/usr/local/sbin/usb-rndis.sh"
install -Dm644 "$SRC/usb-rndis.service" "$ROOTFS/etc/systemd/system/usb-rndis.service"
install -Dm644 "$SRC/usb-rndis.network" "$ROOTFS/etc/systemd/network/20-usb-rndis.network"

# Enable services via chroot
chroot "$ROOTFS" systemctl enable usb-rndis.service 2>/dev/null || \
    ln -sf /etc/systemd/system/usb-rndis.service \
           "$ROOTFS/etc/systemd/system/multi-user.target.wants/usb-rndis.service"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "Post-install hook complete for salami"
log ""
log "Next steps:"
log "  1. Reboot the device"
log "  2. Connect USB cable"
log "  3. ssh droidian@192.168.2.15  (password: 1234)"
log "  4. For ADB into Android container: adb connect <device-ip>:5555"
