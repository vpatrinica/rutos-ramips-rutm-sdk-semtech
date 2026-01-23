#
# Copyright (C) 2025 Teltonika
#
# SX1302 LoRa Packet Forwarder Package for OpenWrt
#

include $(TOPDIR)/rules.mk

PKG_NAME:=pforwarder
PKG_VERSION:=2.0.2
PKG_RELEASE:=1

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE.TXT
PKG_MAINTAINER:=Teltonika

include $(INCLUDE_DIR)/package.mk

define Package/pforwarder
	SECTION:=base
	CATEGORY:=Base system
	TITLE:=SX1302 LoRa Packet Forwarder
	DEPENDS:=+librt +libpthread
	ifeq (m, $(CONFIG_PACKAGE_pforwarder))
		PKG_TLT_NAME:=pforwarder
		PKG_ROUTER:=$(TLT_PLATFORM_NAME)
	endif
endef

define Package/pforwarder/description
	The LoRa Packet Forwarder is a program running on the host of a LoRa
	gateway that forwards RF packets received by the concentrator (SX1302)
	to a server through an IP/UDP link, and emits RF packets that are
	sent by the server.
endef

define Package/pforwarder/conffiles
/etc/lora/global_conf.json
endef

# Build preparation - copy source files to build dir
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./libtools $(PKG_BUILD_DIR)/
	$(CP) ./libloragw $(PKG_BUILD_DIR)/
	$(CP) ./packet_forwarder $(PKG_BUILD_DIR)/
	$(CP) ./util_chip_id $(PKG_BUILD_DIR)/
	$(CP) ./util_net_downlink $(PKG_BUILD_DIR)/
	$(CP) ./util_boot $(PKG_BUILD_DIR)/
	$(CP) ./util_spectral_scan $(PKG_BUILD_DIR)/
	$(CP) ./tools $(PKG_BUILD_DIR)/
	$(CP) ./VERSION $(PKG_BUILD_DIR)/
	$(CP) ./src_Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) ./target.cfg $(PKG_BUILD_DIR)/
endef

# Build the packet forwarder and utilities
define Build/Compile
	# Build libtools
	$(MAKE) -C $(PKG_BUILD_DIR)/libtools \
		CC="$(TARGET_CC)" \
		AR="$(TARGET_CROSS)ar" \
		CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) -O2 -Wall -Wextra -std=c99 -Iinc -I." \
		all

	# Build libloragw
	$(MAKE) -C $(PKG_BUILD_DIR)/libloragw \
		CC="$(TARGET_CC)" \
		AR="$(TARGET_CROSS)ar" \
		CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) -O2 -Wall -Wextra -std=c99 -Iinc -I. -I../libtools/inc" \
		libloragw.a

	# Build packet forwarder
	$(MAKE) -C $(PKG_BUILD_DIR)/packet_forwarder \
		CC="$(TARGET_CC)" \
		AR="$(TARGET_CROSS)ar" \
		CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) -O2 -Wall -Wextra -std=c99 -Iinc -I. -I../libtools/inc" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		LGW_PATH="../libloragw" \
		LIB_PATH="../libtools" \
		all

	# Build util_chip_id
	$(MAKE) -C $(PKG_BUILD_DIR)/util_chip_id \
		CC="$(TARGET_CC)" \
		AR="$(TARGET_CROSS)ar" \
		CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) -O2 -Wall -Wextra -std=c99 -Iinc -I. -I../libtools/inc -I../libloragw/inc" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		LGW_PATH="../libloragw" \
		LIB_PATH="../libtools" \
		all
endef

# Install the binaries and configuration files
define Package/pforwarder/install
	# Install main binaries
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/packet_forwarder/lora_pkt_fwd $(1)/usr/bin/lora_pkt_fwd
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/util_chip_id/chip_id $(1)/usr/bin/chip_id

	# Install reset script
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/packet_forwarder/reset_lgw.sh $(1)/usr/sbin/reset_lgw.sh

	# Install configuration files
	$(INSTALL_DIR) $(1)/etc/lora
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/packet_forwarder/global_conf.json $(1)/etc/lora/global_conf.json

	# Install init script
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/pforwarder.init $(1)/etc/init.d/pforwarder
endef

$(eval $(call BuildPackage,pforwarder))
