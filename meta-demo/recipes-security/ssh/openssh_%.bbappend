FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://10-demo-hardening.conf"

do_install:append() {
    install -d ${D}${sysconfdir}/ssh/sshd_config.d
    install -m 0644 ${WORKDIR}/10-demo-hardening.conf ${D}${sysconfdir}/ssh/sshd_config.d/10-demo-hardening.conf
}

FILES:${PN} += "${sysconfdir}/ssh/sshd_config.d/10-demo-hardening.conf"
