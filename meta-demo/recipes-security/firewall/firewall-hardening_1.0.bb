SUMMARY = "Firewall and sysctl hardening baseline for the demo image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = "file://firewall.sh \
           file://firewall.service \
           file://99-demo-hardening.conf"

S = "${WORKDIR}"

RDEPENDS:${PN} = "iptables"

SYSTEMD_SERVICE:${PN} = "firewall.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/firewall.sh ${D}${sbindir}/demo-firewall

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/firewall.service ${D}${systemd_system_unitdir}/firewall.service

    install -d ${D}${sysconfdir}/sysctl.d
    install -m 0644 ${WORKDIR}/99-demo-hardening.conf ${D}${sysconfdir}/sysctl.d/99-demo-hardening.conf
}

FILES:${PN} += " \
    ${sbindir}/demo-firewall \
    ${systemd_system_unitdir}/firewall.service \
    ${sysconfdir}/sysctl.d/99-demo-hardening.conf \
"
