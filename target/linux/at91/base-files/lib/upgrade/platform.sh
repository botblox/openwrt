REQUIRE_IMAGE_METADATA=1

platform_check_image() {
	local board="$(board_name)"
	local board_dir cmd data_ubivol fit_flags fit_mtd fit_size fit_ubivol image_compat kernel_size
	local root_ubidev root_ubivol rootfs_capacity rootfs_data_ebs rootfs_ebs
	local rootfs_mtd rootfs_mtd_size rootfs_mtd_size_hex rootfs_size rootfs_type
	local ubi_avail_ebs ubi_leb_size

	case "$board" in
	botblox,sam9x75-routercore)
		# check sysupgrade is a tar directory
		nand_do_platform_check "$board" "$1" || {
			v "Firmware is not a valid RouterCore sysupgrade archive"
			return 1
		}
		cmd="$(identify_if_gzip "$1")cat"
		board_dir="$($cmd < "$1" | tar tf - | grep -m 1 '^sysupgrade-.*/$')"
		board_dir="${board_dir%/}"
		[ -n "$board_dir" ] || {
			v "Firmware is not a sysupgrade archive"
			return 1
		}

        # basic check to ensure firmware metadata supports routercore
		fwtool_check_image "$1" || {
			v "Firmware metadata does not support $board"
			return 1
		}

        # check the compatibility version - we hopefully will never need to change this but only for the case
        # when the NAND layout has undergone changes.
		json_load "$(cat /tmp/sysupgrade.meta)" || {
			v "Unable to read firmware compatibility metadata"
			return 1
		}
		json_get_var image_compat compat_version
		[ "$image_compat" = "1.0" ] || {
			v "Unsupported firmware compatibility version: ${image_compat:-missing}"
			return 1
		}

		# ensure that there is a raw MTD partition (not UBI volume or UBIFS partition) called 'fit' for kernel+dtb
		fit_mtd="$(find_mtd_index fit)"
		[ -n "$fit_mtd" ] || {
			v "Raw MTD partition 'fit' was not found"
			return 1
		}
		fit_flags="$(cat "/sys/class/mtd/mtd${fit_mtd}/flags" 2>/dev/null)"
		[ -n "$fit_flags" ] && [ $((fit_flags & 0x400)) -ne 0 ] || {
			v "Raw MTD partition 'fit' is not writable"
			return 1
		}
		# ensure that this 'fit' partition is actually raw MTD
		for fit_ubivol in /sys/class/ubi/ubi*_*; do
			[ -r "$fit_ubivol/name" ] || continue
			[ "$(cat "$fit_ubivol/name")" != "fit" ] || {
				v "FIT must use raw MTD, not UBI volume $(basename "$fit_ubivol")"
				return 1
			}
		done

		# Note that we must keep this limit synchronized with KERNEL_SIZE in the image recipe.
        # This could change with time
		kernel_size=$((6400 * 1024))
		fit_size="$($cmd < "$1" | tar xOf - "$board_dir/kernel" | wc -c)"
		[ "$fit_size" -gt 0 ] || {
			v "Sysupgrade archive has no FIT kernel member"
			return 1
		}
		[ "$fit_size" -le "$kernel_size" ] || {
			v "FIT kernel exceeds KERNEL_SIZE: $fit_size > $kernel_size bytes"
			return 1
		}

		# likewise, check that 'root' partition is actually UBIFS, not raw MTD or UBI block volume
		rootfs_type="$(identify_tar "$1" "$cmd" "$board_dir/root")"
		[ "$rootfs_type" = "ubifs" ] || {
			v "Sysupgrade root member must be UBIFS, not $rootfs_type"
			return 1
		}

		# check that a ubifs root is present
		rootfs_size="$($cmd < "$1" | tar xOf - "$board_dir/root" | wc -c)"
		[ "$rootfs_size" -gt 0 ] || {
			v "Sysupgrade archive has no UBIFS root member"
			return 1
		}

		# check if we have an MTD partition called rootfs and check the size of the UBIFS root in updated binary will fit inside
		# physical MTD rootfs partition
		rootfs_mtd=5
		[ "$(cat "/sys/class/mtd/mtd${rootfs_mtd}/name" 2>/dev/null)" = "rootfs" ] && \
			[ "$(cat "/sys/class/mtd/mtd${rootfs_mtd}/type" 2>/dev/null)" = "nand" ] || {
			v "MTD partition mtd${rootfs_mtd} is not the physical rootfs NAND partition"
			return 1
		}
		rootfs_mtd_size="$(cat "/sys/class/mtd/mtd${rootfs_mtd}/size" 2>/dev/null)"
		if [ -z "$rootfs_mtd_size" ]; then
			rootfs_mtd_size_hex="$(awk -v mtd="mtd${rootfs_mtd}:" \
				'$1 == mtd { print $2; exit }' /proc/mtd)"
			[ -z "$rootfs_mtd_size_hex" ] || \
				rootfs_mtd_size=$((0x$rootfs_mtd_size_hex))
		fi
		[ -n "$rootfs_mtd_size" ] || {
			v "Unable to determine the rootfs MTD partition size"
			return 1
		}
		[ "$rootfs_size" -le "$rootfs_mtd_size" ] || {
			v "UBIFS root exceeds rootfs MTD partition: $rootfs_size > $rootfs_mtd_size bytes"
			return 1
		}

		# Account for UBI metadata, bad-block reserves and any rootfs_data volume that nand_do_upgrade removes before recreating rootfs.
		root_ubidev="ubi0"
		[ "$(cat "/sys/class/ubi/${root_ubidev}/mtd_num" 2>/dev/null)" = "$rootfs_mtd" ] || {
			v "UBI device $root_ubidev is not attached to mtd$rootfs_mtd"
			return 1
		}
		root_ubivol="$(nand_find_volume "$root_ubidev" rootfs)"
		[ -n "$root_ubidev" ] && [ -n "$root_ubivol" ] || {
			v "Unable to determine the current rootfs UBI volume"
			return 1
		}
		ubi_avail_ebs="$(cat "/sys/class/ubi/$root_ubidev/avail_eraseblocks" 2>/dev/null)"
		ubi_leb_size="$(cat "/sys/class/ubi/$root_ubidev/eraseblock_size" 2>/dev/null)"
		rootfs_ebs="$(cat "/sys/class/ubi/$root_ubivol/reserved_ebs" 2>/dev/null)"
		rootfs_data_ebs=0
		data_ubivol="$(nand_find_volume "$root_ubidev" rootfs_data)"
		[ -z "$data_ubivol" ] || \
			rootfs_data_ebs="$(cat "/sys/class/ubi/$data_ubivol/reserved_ebs" 2>/dev/null)"
		[ -n "$ubi_avail_ebs" ] && [ -n "$ubi_leb_size" ] && \
			[ -n "$rootfs_ebs" ] && [ -n "$rootfs_data_ebs" ] || {
			v "Unable to determine usable rootfs UBI capacity"
			return 1
		}
		rootfs_capacity=$(((ubi_avail_ebs + rootfs_ebs + rootfs_data_ebs) * ubi_leb_size))
		[ "$rootfs_size" -le "$rootfs_capacity" ] || {
			v "UBIFS root exceeds usable rootfs capacity: $rootfs_size > $rootfs_capacity bytes"
			return 1
		}
		;;
	*)
		return 1
		;;
	esac
}

routercore_do_upgrade() {
	local board_dir cmd kernel_size rootfs_size root_ubivol

	cmd="$(identify_if_gzip "$1")cat"
	board_dir="$($cmd < "$1" | tar tf - | grep -m 1 '^sysupgrade-.*/$')"
	board_dir="${board_dir%/}"
	kernel_size="$($cmd < "$1" | tar xOf - "$board_dir/kernel" | wc -c)"
	rootfs_size="$($cmd < "$1" | tar xOf - "$board_dir/root" | wc -c)"
	root_ubivol="$(nand_find_volume ubi0 rootfs)"

	[ -n "$root_ubivol" ] && [ "$kernel_size" -gt 0 ] && [ "$rootfs_size" -gt 0 ] || {
		echo "cannot resolve RouterCore upgrade images or rootfs volume"
		nand_do_upgrade_failed
	}

	# upgrade rootfs first, abort if that fails
	# upgrade fit if rootfs suceeds
	sync
	$cmd < "$1" | tar xOf - "$board_dir/root" | \
		ubiupdatevol "/dev/$root_ubivol" -s "$rootfs_size" - || nand_do_upgrade_failed
	$cmd < "$1" | tar xOf - "$board_dir/kernel" | \
		mtd write - fit || nand_do_upgrade_failed

	nand_do_upgrade_success
}

platform_do_upgrade() {
	case "$(board_name)" in
	botblox,sam9x75-routercore)
		CI_KERNPART="fit"
		CI_UBIPART="rootfs"
		CI_ROOTPART="rootfs"
		# RouterCore boots from ubi0 on mtd5 so avoid duplicate rootfs MTD
		# name exported by GLUEBI (emulated UBI rootfs) while upgrading the currently running image.
		nand_find_ubi() {
			[ "$1" = "rootfs" ] || return 1
			[ "$(cat /sys/class/ubi/ubi0/mtd_num 2>/dev/null)" = "5" ] || return 1
			ubi_mknod /sys/class/ubi/ubi0
			echo ubi0
		}
		routercore_do_upgrade "$1"
		;;
	esac
}
