SUMMARY = "Persistent data layout for the demo image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = "file://data-layout.service \
           file://data-layout.sh"

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "data-layout.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/data-layout.service ${D}${systemd_system_unitdir}/data-layout.service

    install -d ${D}${libexecdir}/demo
    install -m 0755 ${WORKDIR}/data-layout.sh ${D}${libexecdir}/demo/data-layout.sh
}

FILES:${PN} += " \
    ${systemd_system_unitdir}/data-layout.service \
    ${libexecdir}/demo/data-layout.sh \
"
