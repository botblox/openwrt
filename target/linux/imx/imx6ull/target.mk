ARCH:=arm
BOARDNAME:=NXP i.MX6ULL Board
CPU_TYPE:=cortex-a7
CPU_SUBTYPE:=neon-vfpv4
KERNELNAME:=zImage dtbs

define Target/Description
	Build firmware images for NXP i.MX6ULL based boards.
endef
