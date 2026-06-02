FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \
    file://10-demo-hardening.conf \
    file://sshdgenkeys-data-layout.conf \
    file://sshd-instance-data-layout.conf \
"

do_install:append() {
    install -d ${D}${sysconfdir}/ssh/sshd_config.d
    install -m 0644 ${WORKDIR}/10-demo-hardening.conf ${D}${sysconfdir}/ssh/sshd_config.d/10-demo-hardening.conf

    sed -i '/^[#[:space:]]*HostKey[[:space:]]/d' ${D}${sysconfdir}/ssh/sshd_config ${D}${sysconfdir}/ssh/sshd_config_readonly
    {
        echo "HostKey /data/config/ssh/ssh_host_rsa_key"
        echo "HostKey /data/config/ssh/ssh_host_ecdsa_key"
        echo "HostKey /data/config/ssh/ssh_host_ed25519_key"
    } >> ${D}${sysconfdir}/ssh/sshd_config
    {
        echo "HostKey /data/config/ssh/ssh_host_rsa_key"
        echo "HostKey /data/config/ssh/ssh_host_ecdsa_key"
        echo "HostKey /data/config/ssh/ssh_host_ed25519_key"
    } >> ${D}${sysconfdir}/ssh/sshd_config_readonly

    install -d ${D}${systemd_system_unitdir}/sshdgenkeys.service.d
    install -m 0644 ${WORKDIR}/sshdgenkeys-data-layout.conf \
        ${D}${systemd_system_unitdir}/sshdgenkeys.service.d/data-layout.conf

    install -d ${D}${systemd_system_unitdir}/sshd@.service.d
    install -m 0644 ${WORKDIR}/sshd-instance-data-layout.conf \
        ${D}${systemd_system_unitdir}/sshd@.service.d/data-layout.conf
}

FILES:${PN}-sshd += " \
    ${sysconfdir}/ssh/sshd_config.d/10-demo-hardening.conf \
    ${systemd_system_unitdir}/sshdgenkeys.service.d/data-layout.conf \
    ${systemd_system_unitdir}/sshd@.service.d/data-layout.conf \
"
