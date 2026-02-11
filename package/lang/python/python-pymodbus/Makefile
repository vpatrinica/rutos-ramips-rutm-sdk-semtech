#
# Copyright (C) 2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python-pymodbus
PKG_VERSION:=2.5.3
PKG_RELEASE:=1

PYPI_NAME:=pymodbus
PKG_HASH:=5ef68c1a109bdb467c830ef003ef2db6494349a5248e4af946fe21c9eefe7e74

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Galen Collins <bashworks@gmail.com>

HOST_BUILD_DEPENDS:=python3/host python-build/host python-installer/host python-wheel/host python-six/host

include ../pypi.mk
include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk
include ../python3-package.mk
include ../python3-host-build.mk

define Package/python3-pymodbus
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Python
  TITLE:=A fully featured modbus protocol stack in python
  URL:=https://github.com/pymodbus-dev/pymodbus
  DEPENDS:=+python3-light +python3-pyserial +python3-logging +python3-urllib +python3-six
endef

define Package/python3-pymodbus/description
  Pymodbus is a full Modbus protocol implementation offering client/server 
  with synchronous/asynchronous API and simulators.
endef

$(eval $(call Py3Package,python3-pymodbus))
$(eval $(call BuildPackage,python3-pymodbus))
$(eval $(call BuildPackage,python3-pymodbus-src))
