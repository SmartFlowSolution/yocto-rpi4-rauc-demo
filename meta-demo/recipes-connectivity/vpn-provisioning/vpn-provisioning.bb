SUMMARY = "VPN provisioning hook for the demo image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = "file://vpn-provisioning.service \
           file://vpn-provisioning.sh"

S = "${WORKDIR}"

SYSTEMD_SERVICE:${PN} = "vpn-provisioning.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/vpn-provisioning.service ${D}${systemd_system_unitdir}/vpn-provisioning.service

    install -d ${D}${libexecdir}/demo
    install -m 0755 ${WORKDIR}/vpn-provisioning.sh ${D}${libexecdir}/demo/vpn-provisioning.sh
}

FILES:${PN} += " \
    ${systemd_system_unitdir}/vpn-provisioning.service \
    ${libexecdir}/demo/vpn-provisioning.sh \
"
