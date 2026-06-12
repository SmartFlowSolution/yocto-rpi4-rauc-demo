SUMMARY = "Yocto Raspberry Pi 4 RAUC demo image"
LICENSE = "MIT"

inherit core-image extrausers

IMAGE_INSTALL = "packagegroup-core-boot"

EXTRA_USERS_PARAMS = "\
    groupadd -r demo; \
    useradd -r -s /usr/sbin/nologin -g demo telemetry-demo; \
    useradd -m -s /bin/sh -g demo demo; \
    usermod -L root; \
    usermod -L demo; \
"

IMAGE_INSTALL:append = " \
    ca-certificates \
    curl \
    data-layout \
    firewall-hardening \
    iproute2 \
    iptables \
    iptables-modules \
    jq \
    kernel-module-tun \
    openssh \
    openssh-sftp-server \
    rauc \
    systemd-conf \
    telemetry-demo \
    util-linux \
    vpn-provisioning \
"

install_demo_ssh_authorized_keys() {
    AUTH_KEYS="${TOPDIR}/../local-provisioning/demo-authorized_keys"

    if [ -f "${AUTH_KEYS}" ]; then
        install -d -m 0700 ${IMAGE_ROOTFS}/home/demo/.ssh
        install -m 0600 "${AUTH_KEYS}" ${IMAGE_ROOTFS}/home/demo/.ssh/authorized_keys
        chown -R demo:demo ${IMAGE_ROOTFS}/home/demo/.ssh
    else
        bbnote "No local demo SSH authorized_keys found at ${AUTH_KEYS}; SSH key provisioning skipped"
    fi
}

ROOTFS_POSTPROCESS_COMMAND += "install_demo_ssh_authorized_keys; "

IMAGE_FSTYPES = "tar.bz2 ext4 wic wic.bz2 wic.bmap"
SDIMG_ROOTFS_TYPE = "ext4"
