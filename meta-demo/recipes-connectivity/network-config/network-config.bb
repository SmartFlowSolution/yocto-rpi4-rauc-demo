SUMMARY = "Optional static IP configuration from /data/config"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = "file://network-config.service \
           file://network-config.sh"

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "network-config.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += "iproute2 systemd"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/network-config.service ${D}${systemd_system_unitdir}/network-config.service

    install -d ${D}${libexecdir}/demo
    install -m 0755 ${WORKDIR}/network-config.sh ${D}${libexecdir}/demo/network-config.sh
}

FILES:${PN} += " \
    ${systemd_system_unitdir}/network-config.service \
    ${libexecdir}/demo/network-config.sh \
"
