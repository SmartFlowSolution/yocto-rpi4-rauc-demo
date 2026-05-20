SUMMARY = "Yocto Raspberry Pi 4 RAUC demo image"
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "read-only-rootfs"

IMAGE_INSTALL = "packagegroup-core-boot"

IMAGE_INSTALL:append = " \
    systemd-conf \
    util-linux \
"

IMAGE_FSTYPES = "tar.bz2 ext4 wic wic.bz2 wic.bmap"
SDIMG_ROOTFS_TYPE = "ext4"
