DEVICE_VARS += UBOOT

include common.mk

# 4MB bootloader (hence 4MB offset)
IMX_KERNELPART_OFFSET = 4
#IMX_KERNELPART_SIZE = 40
#IMX_ROOTFSPART_OFFSET = 64
#IMX_IMAGE_SIZE = $(shell echo $$((($(IMX_ROOTFSPART_OFFSET) + $(CONFIG_TARGET_ROOTFS_PARTSIZE)))))

define Build/imx-combined-image-prepare
	rm -rf $@.boot
	mkdir -p $@.boot
endef

define Build/imx-combined-image-clean
	rm -rf $@.boot
endef

define Build/imx-combined-image
	$(CP) $(IMAGE_KERNEL) $@.boot/$(KERNEL_NAME)

	$(foreach dts,$(DEVICE_DTS), \
		$(CP) \
			$(DTS_DIR)/$(dts).dtb \
			$@.boot/;
	)

	PARTOFFSET="$(IMX_KERNELPART_OFFSET)M" PADDING=1 \
    $(if $(filter $(1),efi),GUID="$(IMG_PART_DISKGUID)") \
    $(SCRIPT_DIR)/gen_image_generic.sh $@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		1024
endef

define Build/imx-no-uboot-no-spl
    $(Build/imx-combined-image-prepare)
	$(Build/imx-combined-image)
    $(Build/imx-combined-image-clean)
endef

define Build/imx-uboot-no-spl
	$(Build/imx-combined-image-prepare)
	$(Build/imx-combined-image)
	dd if=$(STAGING_DIR_IMAGE)/$(UBOOT)-u-boot.imx of=$@ bs=1024 seek=1 conv=notrunc
	$(Build/imx-combined-image-clean)
endef

define Device/Default
  PROFILES := Default
  FILESYSTEMS := ext4
  KERNEL_INSTALL := 1
  KERNEL_NAME := zImage
  KERNEL := kernel-bin
  DTS_DIR := $(DTS_DIR)/nxp/imx
endef

define Device/botblox_ruggedsom
  $(call Device/Default)
  DEVICE_VENDOR := BotBlox
  DEVICE_MODEL := RUGGEDSOM
  DEVICE_VARIANT := eMMC Boot
  BOARD_NAME := RuggedSOM
  DEVICE_PACKAGES += firmware-sdma u-boot-imx6ull
  UBOOT_NAME:=imx6ull-u-boot-dtb.imx
  UBOOT := ruggedsom
  DEVICE_DTS := imx6ull-botblox-swr-som
  IMAGES := sysupgrade.bin emmc.img emmc-efi.img
  IMAGE/emmc.img := imx-uboot-no-spl
  IMAGE/emmc-efi.img := imx-uboot-no-spl efi
  IMAGE/emmc-no-uboot.img := imx-no-uboot-no-spl
  IMAGE/emmc-no-uboot-efi.img := imx-no-uboot-no-spl efi
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += botblox_ruggedsom
