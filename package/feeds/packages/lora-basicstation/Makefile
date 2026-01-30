#
# Copyright (C) 
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
#
include $(TOPDIR)/rules.mk

PKG_NAME:=lora-basicstation
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

#PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
#PKG_SOURCE_URL:=
#PKG_HASH:=

#PKG_MAINTAINER:=
#PKG_LICENSE:=BSD-3-Clause
#PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=sx1302_hal mbedtls

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/lora-basicstation
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=LoRaWAN
  TITLE:=LoRaWAN Basic Station
  DEPENDS:=+kmod-usb-acm
endef

define Package/lora-basicstation/description
  LoRaWAN Basic Station. The LoRaWAN Gateway Software.
endef

define Package/lora-basicstation/conffiles
/etc/config/basicstation
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	rm -rf $(PKG_BUILD_DIR)/deps/
	rm -f $(PKG_BUILD_DIR)/makefile
	rm -f $(PKG_BUILD_DIR)/makefile.s2core
	rm -f $(PKG_BUILD_DIR)/setup.gmk
endef

define Package/lora-basicstation/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/station $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/basicstation $(1)/etc/config/basicstation
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/basicstation $(1)/etc/init.d/basicstation
endef

$(eval $(call BuildPackage,lora-basicstation))
