# c4-ea-homeassistant — Buildroot external.mk.
include $(sort $(wildcard $(BR2_EXTERNAL_OHCHA_PATH)/package/*/*.mk))
