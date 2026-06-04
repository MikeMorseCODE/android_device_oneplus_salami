#!/bin/bash
# flash-all.sh — Flash Droidian/Halium images to OnePlus 11 (salami)
#
# Run from the directory containing the built images, or pass the image
# directory as the first argument:
#   ./flash-all.sh                            # images in current dir
#   ./flash-all.sh out/target/product/salami  # explicit path
#
# Requirements:
#   - fastboot >= 34.0.5 (for dynamic partition / fastbootd support)
#   - Device in fastboot mode (hold Vol-Down + Power at boot, or
#     'adb reboot bootloader' from Android)
#   - Unlocked bootloader (Settings → About → tap Build 7x →
#     Developer Options → OEM unlocking)
#
# What this script does NOT touch:
#   - userdata   — formatted and populated by halium-install
#   - persist    — calibration data; wiping breaks fingerprint/camera
#   - modemst*   — modem NV items; wiping breaks IMEI
#
# After flashing, run halium-install on the device to place the
# Droidian rootfs.img on userdata.

set -euo pipefail

IMGDIR="${1:-$(pwd)}"

die() { echo "ERROR: $*" >&2; exit 1; }

check_tool() {
    command -v "$1" &>/dev/null || die "'$1' not found in PATH"
}

check_tool fastboot

echo "==> Checking device presence"
fastboot devices | grep -q . || die "No device in fastboot mode found"

echo "==> Images directory: $IMGDIR"
for img in boot.img vendor_boot.img dtbo.img vbmeta.img vbmeta_system.img \
           system.img vendor.img vendor_dlkm.img odm.img \
           system_ext.img product.img; do
    [ -f "$IMGDIR/$img" ] || die "Missing image: $IMGDIR/$img"
done

# ---------------------------------------------------------------------------
# Step 1: Flash bootloader-side partitions to both A/B slots
# ---------------------------------------------------------------------------
echo
echo "==> [1/4] Flashing boot partitions (both slots)"

fastboot flash --slot=all boot           "$IMGDIR/boot.img"
fastboot flash --slot=all vendor_boot    "$IMGDIR/vendor_boot.img"
fastboot flash --slot=all dtbo           "$IMGDIR/dtbo.img"

# ---------------------------------------------------------------------------
# Step 2: Flash vbmeta with AVB verification disabled
# Using --disable-verity --disable-verification lets unsigned/re-signed
# images boot without orange-state warning or dm-verity failures.
# ---------------------------------------------------------------------------
echo
echo "==> [2/4] Flashing vbmeta (AVB disabled for development)"

fastboot flash --slot=all vbmeta \
    --disable-verity --disable-verification \
    "$IMGDIR/vbmeta.img"

fastboot flash --slot=all vbmeta_system \
    --disable-verity --disable-verification \
    "$IMGDIR/vbmeta_system.img"

# ---------------------------------------------------------------------------
# Step 3: Flash dynamic (logical) partitions via fastbootd
# Dynamic partitions (system, vendor, odm, ...) live inside 'super' and
# must be flashed while the device is in fastbootd mode, not bootloader.
# ---------------------------------------------------------------------------
echo
echo "==> [3/4] Rebooting to fastbootd for dynamic partitions"

fastboot reboot fastboot
echo "    Waiting for fastbootd..."
fastboot wait-for-fastboot 2>/dev/null || sleep 5
fastboot devices | grep -q . || die "Device not found in fastbootd"

echo "    Flashing dynamic partitions (both slots)"
fastboot flash --slot=all system       "$IMGDIR/system.img"
fastboot flash --slot=all vendor       "$IMGDIR/vendor.img"
fastboot flash --slot=all vendor_dlkm  "$IMGDIR/vendor_dlkm.img"
fastboot flash --slot=all odm          "$IMGDIR/odm.img"
fastboot flash --slot=all system_ext   "$IMGDIR/system_ext.img"
fastboot flash --slot=all product      "$IMGDIR/product.img"

# system_dlkm is optional (GKI modules); skip if absent
if [ -f "$IMGDIR/system_dlkm.img" ]; then
    fastboot flash --slot=all system_dlkm "$IMGDIR/system_dlkm.img"
fi

# ---------------------------------------------------------------------------
# Step 4: Set active slot to a and reboot
# ---------------------------------------------------------------------------
echo
echo "==> [4/4] Setting active slot to a and rebooting"

fastboot set_active a
fastboot reboot

echo
echo "Done. Device is rebooting into Android (first boot will be slow)."
echo
echo "Next steps:"
echo "  1. Wait for Android to fully boot (verify with 'adb devices')"
echo "  2. Run halium-install to place the Droidian rootfs:"
echo "       adb push rootfs.img /sdcard/rootfs.img"
echo "       adb shell 'su -c halium-install /sdcard/rootfs.img'"
echo "  3. Reboot. Device should boot into Droidian."
echo "  4. SSH in: ssh droidian@192.168.2.15  (USB cable, password: 1234)"
