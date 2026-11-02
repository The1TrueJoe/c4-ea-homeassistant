################################################################################
#
# ha-core
#
################################################################################

# No source: ships the installer, its config and the init script. HA itself
# comes from PyPI on the box (S97homeassistant -> ha-install).
HA_CORE_LICENSE = MIT

define HA_CORE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(HA_CORE_PKGDIR)/ha-install \
		$(TARGET_DIR)/opt/ha/bin/ha-install
	mkdir -p $(TARGET_DIR)/etc
	printf 'HA_VERSION=%s\nHA_DIR=/data/ha\n' \
		$(call qstrip,$(BR2_PACKAGE_HA_CORE_HA_VERSION)) \
		> $(TARGET_DIR)/etc/ha-core.conf
endef

define HA_CORE_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(HA_CORE_PKGDIR)/S97homeassistant \
		$(TARGET_DIR)/etc/init.d/S97homeassistant
endef

$(eval $(generic-package))
