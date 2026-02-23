include $(TOPDIR)/rules.mk

APP_TITLE:=VuCI UI Support for LoRaWAN BasicStation
APP_NAME:=$(notdir ${CURDIR})
CLOSED_GPL_INSTALL:=y
PKG_RELEASE:=12

ifeq (m, $(CONFIG_PACKAGE_$(APP_NAME)))
	APP_TLT_NAME:=LoRaWAN BasicStation
	APP_ROUTER:=$(TLT_PLATFORM_NAME)
endif

define Package/$(APP_NAME)/description
	LoRaWAN BasicStation UI application
endef

include ../app.mk

# call BuildPackage - OpenWrt buildroot signature
