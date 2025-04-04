. /lib/imx.sh

RAMFS_COPY_BIN='blkid'
RAMFS_COPY_DATA='/etc/fstab'

botblox_imx_emmc_mount_boot() {
	mkdir -p /boot
	[ -f /boot/zImage ] || {
		mount -o rw,noatime $(bootpart_from_uuid) /boot > /dev/null
	}
}

botblox_imx_emmc_do_upgrade() {
	local board_dir="$(tar tf "${1}" | grep -m 1 '^sysupgrade-.*/$')"
	board_dir="${board_dir%/}"

	botblox_imx_emmc_mount_boot

	local lists="$(tar tf "${1}")"
	echo ${lists}
	echo "${1}"
	ls -al /
	ls -al /boot
	ls -al ${board_dir}
	
	echo "Add new zImage"
	get_image "$1" | tar Oxf - ${board_dir}/kernel > /boot/zImage-new && \
		mv /boot/zImage-new /boot/zImage && \
		sync && \
		get_image "$1" | tar Oxf - ${board_dir}/root > $(rootpart_from_uuid) && \
		sync

	umount /boot
}

botblox_imx_emmc_copy_config() {
	botblox_imx_emmc_mount_boot
	cp -af "$UPGRADE_BACKUP" "/boot/$BACKUP_FILE"
	sync
	umount /boot
}

enable_image_metadata_check() {
	case "$(board_name)" in
	botblox,ruggedsom)
		REQUIRE_IMAGE_METADATA=1
		;;
	esac
}
enable_image_metadata_check

platform_check_image() {
	local board=$(board_name)

	case "$board" in
	botblox,ruggedsom)
		return 0
		;;
	esac

	echo "Sysupgrade is not yet supported on $board."
	return 1
}

platform_do_upgrade() {
	local board=$(board_name)

	case "$board" in
	botblox,ruggedsom)
		botblox_imx_emmc_do_upgrade "$1"
		;;
	esac
}

platform_copy_config() {
	local board=$(board_name)

	case "$board" in
	botblox,ruggedsom)
		botblox_imx_emmc_copy_config
		;;
	esac
}
