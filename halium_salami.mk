#
# Copyright (C) 2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# Halium/Droidian product configuration for OnePlus 11 (salami).
# Build with:  lunch halium_salami-userdebug && mka bacon
#

# Inherit core architecture and telephony base
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit salami device config (brings in device.mk → common.mk)
$(call inherit-product, device/oneplus/salami/device.mk)

# Use LineageOS as the Android HAL build scaffolding.
# Droidian replaces the LineageOS UI; the LineageOS vendor tree is kept
# only because it provides the Qualcomm proprietary blobs.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# ---------------------------------------------------------------------------
# Product identity
# ---------------------------------------------------------------------------
PRODUCT_NAME     := halium_salami
PRODUCT_DEVICE   := salami
PRODUCT_BRAND    := OnePlus
PRODUCT_MANUFACTURER := OnePlus
PRODUCT_MODEL    := CPH2449

PRODUCT_SYSTEM_NAME   := CPH2449
PRODUCT_SYSTEM_DEVICE := OP594DL1
PRODUCT_GMS_CLIENTID_BASE := android-oneplus

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="CPH2449EEA-user 14 TP1A.220905.001 T.R4T3.1a1ad1b_1-6 release-keys" \
    TARGET_DEVICE=$(PRODUCT_SYSTEM_DEVICE) \
    TARGET_PRODUCT=$(PRODUCT_SYSTEM_NAME)

BUILD_FINGERPRINT := OnePlus/CPH2449EEA/OP594DL1:14/TP1A.220905.001/T.R4T3.1a1ad1b_1-6:user/release-keys

# ---------------------------------------------------------------------------
# Halium / Droidian overrides
# ---------------------------------------------------------------------------

# Disable file-based encryption.
# Droidian does not use Android FBE; userdata must be mountable by
# halium-boot without Android encryption keys so rootfs.img is accessible.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.crypto.type=none \
    ro.crypto.state=unsupported

# Force verified boot state to green so test-signed (or re-signed) images
# are accepted by the bootloader without triggering orange-state warnings.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.boot.verifiedbootstate=green

# Halium container identification (also set at runtime by init.halium.rc)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.halium.device=salami \
    ro.halium.version=12 \
    ro.halium.platform=kalama

# Build tag so flashable images are identifiable
PRODUCT_PROPERTY_OVERRIDES += \
    ro.build.tags=halium-droidian
