SUMMARY = "Yocto Raspberry Pi 4 RAUC demo image"
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "read-only-rootfs"

IMAGE_INSTALL = "packagegroup-core-boot"

IMAGE_INSTALL:append = " \
    systemd-conf \
    util-linux \
    data-layout \
    network-config \
    iproute2 \
    telemetry-demo \
    vpn-provisioning \
"

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

install_demo_network_tools_links() {
    install -d ${IMAGE_ROOTFS}${bindir}

    if [ -x ${IMAGE_ROOTFS}${base_sbindir}/ip ] && [ ! -e ${IMAGE_ROOTFS}${bindir}/ip ]; then
        ln -s ${base_sbindir}/ip ${IMAGE_ROOTFS}${bindir}/ip
    elif [ -x ${IMAGE_ROOTFS}${sbindir}/ip ] && [ ! -e ${IMAGE_ROOTFS}${bindir}/ip ]; then
        ln -s ${sbindir}/ip ${IMAGE_ROOTFS}${bindir}/ip
    fi
}

ROOTFS_POSTPROCESS_COMMAND += "ensure_demo_users; install_demo_network_tools_links; "

IMAGE_FSTYPES = "tar.bz2 ext4 wic wic.bz2 wic.bmap"
SDIMG_ROOTFS_TYPE = "ext4"
