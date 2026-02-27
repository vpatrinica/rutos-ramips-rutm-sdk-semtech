#
# Copyright (C) 2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-easye4
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include ../python3-package.mk

define Package/python3-easye4
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=Eaton easyE4 API Integration
  URL:=https://example.com/easye4
  DEPENDS:=+python3-light +python3-requests +python3-logging +python3-pahomqtt +python3-pymodbus
endef

define Package/python3-easye4/description
  Python package for Eaton easyE4 communication mirroring Node-RED nodes.
endef

define Package/easye4-service
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Eaton easyE4 Polling Service
  DEPENDS:=+python3-easye4
endef

define Package/easye4-service/description
  Init scripts and configuration for running the easyE4 polling service.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/easye4-service/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/easye4.config $(1)/etc/config/easye4
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/easye4.init $(1)/etc/init.d/easye4
	$(INSTALL_DIR) $(1)/etc/hotplug.d/tty
	$(INSTALL_BIN) ./files/99-modbus-alias.sh $(1)/etc/hotplug.d/tty/99-modbus-alias.sh
endef

$(eval $(call Py3Package,python3-easye4))
$(eval $(call BuildPackage,python3-easye4))
$(eval $(call BuildPackage,python3-easye4-src))
$(eval $(call BuildPackage,easye4-service))
