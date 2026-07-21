# AndroidProducts.mk untuk build TWRP.
# Dipasang oleh build_twrp.sh (menimpa AndroidProducts.mk bawaan device tree,
# yang menunjuk lineage_ms013g — produk itu tak bisa dibuild di tree TWRP/AOSP).

PRODUCT_MAKEFILES += \
    $(LOCAL_DIR)/twrp_ms013g.mk

COMMON_LUNCH_CHOICES := \
    twrp_ms013g-eng
