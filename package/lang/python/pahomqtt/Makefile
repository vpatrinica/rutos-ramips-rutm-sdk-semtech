#
# Copyright (C) 2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=pahomqtt
PKG_VERSION:=1.6.1
PKG_RELEASE:=1

PYPI_NAME:=paho-mqtt
PKG_HASH:=2a8291c81623aec00372b5a85558a372c747cbca8e9934dfe218638b8eefc26f

PKG_LICENSE:=EPL-2.0
PKG_LICENSE_FILES:=LICENSE.txt
PKG_MAINTAINER:=Roger Light <roger@atchoo.org>

include ../pypi.mk
include $(INCLUDE_DIR)/package.mk
include ../python3-package.mk

define Package/python3-pahomqtt
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=MQTT version 5.0/3.1.1/3.1 client library
  URL:=https://github.com/eclipse/paho.mqtt.python
  DEPENDS:=+python3-light +python3-logging +python3-openssl
endef

define Package/python3-pahomqtt/description
  The Paho Python Client provides a client class with support for MQTT v5.0, 
  v3.1.1, and v3.1 on Python 3.
endef

$(eval $(call Py3Package,python3-pahomqtt))
$(eval $(call BuildPackage,python3-pahomqtt))
$(eval $(call BuildPackage,python3-pahomqtt-src))
