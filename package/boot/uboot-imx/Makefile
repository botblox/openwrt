#
# Copyright (C) 2013-2014 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

# PKG_VERSION:=2022.01
# PKG_RELEASE:=5
# PKG_HASH:=81b4543227db228c03f8a1bf5ddbc813b0bb8f6555ce46064ef721a6fc680413

PKG_NAME:=uboot-imx
PKG_VERSION:=lf_v2024.04
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/nxp-imx/uboot-imx
PKG_SOURCE_VERSION:=lf_v2024.04

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk

define U-Boot/Default
  BUILD_TARGET:=imx
  UBOOT_IMAGE:=u-boot.imx
endef

define U-Boot/apalis_imx6
  NAME:=Toradex Apalis
  UBOOT_IMAGE:=SPL u-boot.img u-boot-with-spl.imx
  UBOOT_MAKE_FLAGS+=SPL u-boot.img u-boot-with-spl.imx
  BUILD_SUBTARGET:=cortexa9
  BUILD_DEVICES:=toradex_apalis
endef

define U-Boot/mx6cuboxi
  NAME:=SolidRun Cubox-i boards
  UBOOT_IMAGE:=SPL u-boot-dtb.img
  UBOOT_MAKE_FLAGS+=SPL u-boot-dtb.img
  BUILD_SUBTARGET:=cortexa9
  BUILD_DEVICES:=solidrun_cubox-i
endef

define U-Boot/pico-pi-imx7d
  NAME:=TechNexion PICO-PI-IMX7D
  UBOOT_IMAGE:=SPL u-boot-dtb.img
  UBOOT_MAKE_FLAGS+=SPL u-boot-dtb.img
  BUILD_SUBTARGET:=cortexa7
  BUILD_DEVICES:=technexion_imx7d-pico-pi
endef

define U-Boot/wandboard
  NAME:=Wandboard Dual Lite/Quad/Solo
  BUILD_SUBTARGET:=cortexa9
  BUILD_DEVICES:=wandboard_dual
endef

define U-Boot/ruggedsom
  NAME:=BotBlox Rugged SOM eMMC
  BUILD_SUBTARGET:=imx6ull
  BUILD_DEVICES:=ruggedsom
  UBOOT_CONFIG:=botblox_swr_som_emmc
  DTB_NAME:=imx6ull-botblox-swr-som-emmc
endef

UBOOT_TARGETS := \
	apalis_imx6 \
	mx6cuboxi \
	pico-pi-imx7d \
	wandboard \
  ruggedsom

UBOOT_MAKE_FLAGS += u-boot.imx

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	$(foreach img,$(UBOOT_IMAGE), \
		$(CP) $(PKG_BUILD_DIR)/$(img) $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-$(img); \
	)
endef

$(eval $(call BuildPackage/U-Boot))
