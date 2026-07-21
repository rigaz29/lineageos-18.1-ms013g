#
# TWRP product config — Samsung Galaxy Grand 2 Duos (ms013g / SM-G7102)
# 32-bit (Cortex-A7, MSM8226). Untuk minimal-manifest-twrp branch twrp-11.
#
# Dipasang otomatis oleh build_twrp.sh ke device/samsung/ms013g/twrp_ms013g.mk
#

# Base sistem inti (ramping, cocok untuk recovery).
# CATATAN: twrp-11 TIDAK punya embedded.mk; aosp_base menarik aplikasi handheld
# yang tak perlu untuk recovery -> pakai base.mk.
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Konfigurasi TWRP (disediakan minimal manifest di vendor/twrp)
$(call inherit-product, vendor/twrp/config/common.mk)

# Konfigurasi device (tree Grand-2-Rebirth yang sudah TWRP-ready)
$(call inherit-product, device/samsung/ms013g/device.mk)

PRODUCT_DEVICE := ms013g
PRODUCT_NAME := twrp_ms013g
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-G7102
PRODUCT_MANUFACTURER := samsung

# Memicu '-include twrp.mk' (semua flag TW_*) di BoardConfigCommon.
# build_twrp.sh juga meng-export WITH_TWRP=true agar terlihat saat parsing BoardConfig.
WITH_TWRP := true
