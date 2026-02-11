include $(TOPDIR)/rules.mk

PKG_NAME:=python-pynacl
PKG_VERSION:=1.6.2
PKG_RELEASE:=1

PYPI_NAME:=PyNaCl
PYPI_SOURCE_NAME:=pynacl
PYTHON3_PKG_WHEEL_NAME:=pynacl
PKG_HASH:=018494d6d696ae03c7e656e5e74cdfd8ea1326962cc401bcf018f1ed8436811c

PKG_MAINTAINER:=Javier Marcet <javier@marcet.info>
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=libffi/host python-cffi/host  # cffi>=1.4.1

PYTHON3_PKG_BUILD_VARS:= \
	SODIUM_INSTALL=system \
	SODIUM_LIB_DIR=$(STAGING_DIR)/usr/lib \
	SODIUM_INC_DIR=$(STAGING_DIR)/usr/include

include ../pypi.mk
include $(INCLUDE_DIR)/package.mk
include ../python3-package.mk

define Package/python3-pynacl
  CATEGORY:=Languages
  SECTION:=lang
  SUBMENU:=Python
  TITLE:=Python binding to the libsodium library
  URL:=https://github.com/pyca/pynacl/
  DEPENDS:=+libsodium +python3-light +python3-cffi +python3-six
endef

define Package/python3-pynacl/description
  PyNaCl is a Python binding to libsodium, which is a fork of the Networking and Cryptography library.
endef

$(eval $(call Py3Package,python3-pynacl))
$(eval $(call BuildPackage,python3-pynacl))
$(eval $(call BuildPackage,python3-pynacl-src))
