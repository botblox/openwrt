DEVICE_VARS += UBOOT

include common.mk

# 16MB bootloader + 40MB kernel
IMX_SD_KERNELPART_SIZE = 40
IMX_SD_KERNELPART_OFFSET = 16
IMX_SD_ROOTFSPART_OFFSET = 64
IMX_SD_IMAGE_SIZE = $(shell echo $$((($(IMX_SD_ROOTFSPART_OFFSET) + \
	$(CONFIG_TARGET_ROOTFS_PARTSIZE)))))

define Build/imx-clean
	# Clean the target
	echo $(IMAGE_KERNEL) , $(IMAGE_ROOTFS)
	rm -f $@
endef

define Build/imx-append
	# append binary
	dd if=$(STAGING_DIR_IMAGE)/$(1) >> $@
endef

define Build/imx-append-kernel
	# append the kernel
	mkdir -p $@.tmp && \
	cp $(IMAGE_KERNEL) $@.tmp && \
	cp $(KDIR)/image-$(firstword $(1)).dtb $@.tmp && \
	make_ext4fs -J -L kernel -l "$(IMX_SD_KERNELPART_SIZE)M" "$@.kernel.part" "$@.tmp" && \
	dd if=$@.kernel.part >> $@ && \
	rm -rf $@.tmp && \
	rm -f $@.kernel.part
endef

define Build/imx-append-uboot
	# append boot loader image
	dd if=$(STAGING_DIR_IMAGE)/$(1) >> $@
endef

define Build/imx-append-sdhead
	# Create the sd file table
	./gen_sdcard_head_img.sh $(STAGING_DIR_IMAGE)/$(1)-sdcard-head.img \
		$(IMX_SD_KERNELPART_OFFSET) $(IMX_SD_KERNELPART_SIZE) \
		$(IMX_SD_ROOTFSPART_OFFSET) $(CONFIG_TARGET_ROOTFS_PARTSIZE)
	dd if=$(STAGING_DIR_IMAGE)/$(1)-sdcard-head.img >> $@
endef

define Device/Default
  PROFILES := Default
  FILESYSTEMS := squashfs ext4
  KERNEL_INSTALL := 1
  KERNEL_NAME := zImage
  KERNEL := kernel-bin
  DTS_DIR := $(DTS_DIR)/nxp/imx
endef

define Device/technexion_imx7d-pico-pi
  DEVICE_VENDOR := TechNexion
  DEVICE_MODEL := PICO-PI-IMX7D
  UBOOT := pico-pi-imx7d
  DEVICE_DTS := imx7d-pico-pi
  DEVICE_PACKAGES := kmod-sound-core kmod-sound-soc-imx kmod-sound-soc-imx-sgtl5000 \
	kmod-can kmod-can-flexcan kmod-can-raw kmod-leds-gpio \
	kmod-input-touchscreen-edt-ft5x06 kmod-usb-hid kmod-btsdio \
	kmod-brcmfmac brcmfmac-firmware-4339-sdio cypress-nvram-4339-sdio
  FILESYSTEMS := squashfs
  KERNEL := kernel-bin | uImage none
  KERNEL_SUFFIX := -uImage
  KERNEL_LOADADDR := 0x80008000
  IMAGES := combined.bin sysupgrade.bin
  IMAGE/combined.bin := append-rootfs | pad-extra 128k | imx-sdcard-raw-uboot
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += technexion_imx7d-pico-pi

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

define Device/botblox_ruggedsom
  $(call Device/Default)
  DEVICE_VENDOR := BotBlox
  DEVICE_MODEL := RUGGEDSOM
  DEVICE_VARIANT := eMMC Boot
  BOARD_NAME := RuggedSOM
  DEVICE_PACKAGES += firmware-sdma u-boot-ruggedsom
  UBOOT := ruggedsom
  DEVICE_DTS := imx6ull-botblox-swr-som
  KERNEL := kernel-bin
  IMAGES := sysupgrade.bin emmc.img emmc-efi.img emmc-no-uboot.img emmc-no-uboot-efi.img
  IMAGE/emmc.img := imx-uboot-no-spl
  IMAGE/emmc-efi.img := imx-uboot-no-spl efi
  IMAGE/emmc-no-uboot.img := imx-no-uboot-no-spl
  IMAGE/emmc-no-uboot-efi.img := imx-no-uboot-no-spl efi
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += botblox_ruggedsom
