SUMMARY = "RAUC update bundle for demo-image"
LICENSE = "MIT"

inherit bundle

RAUC_BUNDLE_COMPATIBLE = "RaspberryPi4"
RAUC_BUNDLE_VERSION = "${DISTRO_VERSION}"
RAUC_BUNDLE_DESCRIPTION = "Demo RAUC bundle for Raspberry Pi 4"

RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_SLOT_rootfs = "demo-image"
RAUC_SLOT_rootfs[fstype] = "ext4"

RAUC_KEY_FILE ?= "${TOPDIR}/../certs/development.key.pem"
RAUC_CERT_FILE ?= "${TOPDIR}/../certs/development.cert.pem"

python __anonymous() {
    import hashlib
    import os

    for source_var, hash_var in (
        ("RAUC_KEY_FILE", "RAUC_KEY_FILE_SHA256"),
        ("RAUC_CERT_FILE", "RAUC_CERT_FILE_SHA256"),
    ):
        path = d.getVar(source_var)
        if path and os.path.exists(path):
            with open(path, "rb") as f:
                digest = hashlib.sha256(f.read()).hexdigest()
        else:
            digest = "missing"

        d.setVar(hash_var, digest)
}

do_bundle[vardeps] += "RAUC_KEY_FILE_SHA256 RAUC_CERT_FILE_SHA256"
