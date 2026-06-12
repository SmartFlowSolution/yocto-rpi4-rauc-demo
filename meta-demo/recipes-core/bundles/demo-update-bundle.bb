SUMMARY = "RAUC update bundle for demo-image"
LICENSE = "MIT"

inherit bundle

RAUC_BUNDLE_COMPATIBLE = "${MACHINE}"
RAUC_BUNDLE_VERSION = "${DISTRO_VERSION}"
RAUC_BUNDLE_DESCRIPTION = "Demo RAUC bundle for Raspberry Pi 4"

RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_SLOT_rootfs = "demo-image"
RAUC_SLOT_rootfs[fstype] = "ext4"

RAUC_KEY_FILE ?= "${TOPDIR}/../certs/development.key.pem"
RAUC_CERT_FILE ?= "${TOPDIR}/../certs/development.cert.pem"
