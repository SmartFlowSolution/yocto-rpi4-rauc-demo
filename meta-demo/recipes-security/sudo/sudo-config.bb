SUMMARY = "Custom sudo rules for demo"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://010_demo_telemtry"

S = "${WORKDIR}"

RDEPENDS:${PN} += "sudo"

FILES:${PN} += "${sysconfdir}/sudoers.d/*"

do_install() {
    install -d ${D}${sysconfdir}/sudoers.d

    install -m 0440 ${WORKDIR}/010_demo_telemtry \
        ${D}${sysconfdir}/sudoers.d/010_demo_telemtry
}
