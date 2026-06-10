SUMMARY = "Yocto Raspberry Pi 4 RAUC demo image"
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "read-only-rootfs"

IMAGE_INSTALL = "packagegroup-core-boot"

IMAGE_INSTALL:append = " \
    sudo \
    sudo-config \
    systemd-conf \
    util-linux \
    data-layout \
    network-config \
    iproute2 \
    iptables \
    iptables-modules \
    firewall-hardening \
    curl \
    jq \
    nano \
    sqlite3 \
    ca-certificates \
    openssh \
    openssh-keygen \
    openssh-sftp-server \
    kernel-module-tun \
    rauc \
    telemetry-demo \
    vpn-provisioning \
"

DEMO_AUTHORIZED_KEYS = "${TOPDIR}/../local-provisioning/demo-authorized_keys"

python __anonymous() {
    import hashlib
    import os

    auth_keys = d.getVar("DEMO_AUTHORIZED_KEYS")
    if auth_keys and os.path.exists(auth_keys):
        with open(auth_keys, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
    else:
        digest = "missing"

    d.setVar("DEMO_AUTHORIZED_KEYS_SHA256", digest)
}

do_rootfs[vardeps] += "DEMO_AUTHORIZED_KEYS_SHA256"

ensure_demo_users() {
    if ! grep -q '^demo:' ${IMAGE_ROOTFS}${sysconfdir}/group; then
        groupadd -R ${IMAGE_ROOTFS} -r demo
    fi

    if ! grep -q '^telemetry-demo:' ${IMAGE_ROOTFS}${sysconfdir}/group; then
        groupadd -R ${IMAGE_ROOTFS} -r telemetry-demo
    fi

    if ! grep -q '^telemetry-demo:' ${IMAGE_ROOTFS}${sysconfdir}/passwd; then
        useradd -R ${IMAGE_ROOTFS} -r -s /usr/sbin/nologin -g telemetry-demo -G demo telemetry-demo
    else
        usermod -R ${IMAGE_ROOTFS} -g telemetry-demo -a -G demo telemetry-demo
    fi

    if ! grep -q '^demo:' ${IMAGE_ROOTFS}${sysconfdir}/passwd; then
        useradd -R ${IMAGE_ROOTFS} -m -s /bin/sh -g demo demo
    fi

    usermod -R ${IMAGE_ROOTFS} -L root
    usermod -R ${IMAGE_ROOTFS} -L demo
}

install_demo_ssh_authorized_keys() {
    AUTH_KEYS="${DEMO_AUTHORIZED_KEYS}"

    if [ -f "${AUTH_KEYS}" ]; then
        install -d -m 0700 ${IMAGE_ROOTFS}/home/demo/.ssh
        install -m 0600 "${AUTH_KEYS}" ${IMAGE_ROOTFS}/home/demo/.ssh/authorized_keys
        chown -R --reference=${IMAGE_ROOTFS}/home/demo ${IMAGE_ROOTFS}/home/demo/.ssh
    else
        bbnote "No local demo SSH authorized_keys found at ${AUTH_KEYS}; SSH key provisioning skipped"
    fi
}

install_demo_network_tools_links() {
    install -d ${IMAGE_ROOTFS}${bindir}

    if [ -x ${IMAGE_ROOTFS}${base_sbindir}/ip ] && [ ! -e ${IMAGE_ROOTFS}${bindir}/ip ]; then
        ln -s ${base_sbindir}/ip ${IMAGE_ROOTFS}${bindir}/ip
    elif [ -x ${IMAGE_ROOTFS}${sbindir}/ip ] && [ ! -e ${IMAGE_ROOTFS}${bindir}/ip ]; then
        ln -s ${sbindir}/ip ${IMAGE_ROOTFS}${bindir}/ip
    fi
}

ROOTFS_POSTPROCESS_COMMAND += "ensure_demo_users; install_demo_ssh_authorized_keys; install_demo_network_tools_links; "

IMAGE_FSTYPES = "tar.bz2 ext4 wic wic.bz2 wic.bmap"
SDIMG_ROOTFS_TYPE = "ext4"
