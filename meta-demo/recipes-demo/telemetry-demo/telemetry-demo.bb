SUMMARY = "Small C++ telemetry service used by the Yocto demo image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9c853a0d127d192d35959802fb62b7e1"

inherit cmake pkgconfig systemd

SRC_URI = " \
    git://github.com/SmartFlowSolution/telemetry-demo.git;protocol=https;branch=main \
    file://data-paths.conf \
"
SRCREV = "f8f9985b037b8badace2aa55eddabcce8139ed9f"

S = "${WORKDIR}/git"

DEPENDS += "sqlite3"

SYSTEMD_SERVICE:${PN} = "telemetry-demo.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install:append() {
    install -d ${D}/opt/telemetry-demo/bin
    if [ -x ${D}${bindir}/telemetry-demo ]; then
        mv ${D}${bindir}/telemetry-demo ${D}/opt/telemetry-demo/bin/telemetry-demo
        rmdir --ignore-fail-on-non-empty ${D}${bindir} || true
    else
        bbfatal "Expected telemetry-demo binary at ${D}${bindir}/telemetry-demo"
    fi

    install -d ${D}${bindir}
    cat > ${D}${bindir}/telemetry-demo <<'EOF'
#!/bin/sh
exec /opt/telemetry-demo/bin/telemetry-demo --config /data/config/telemetry-demo/config.json "$@"
EOF
    chmod 0755 ${D}${bindir}/telemetry-demo

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/packaging/telemetry-demo.service ${D}${systemd_system_unitdir}/telemetry-demo.service
    sed -i \
        -e 's#/usr/bin/telemetry-demo#/opt/telemetry-demo/bin/telemetry-demo#g' \
        -e 's#ExecStart=telemetry-demo#ExecStart=/opt/telemetry-demo/bin/telemetry-demo#g' \
        -e 's#/etc/telemetry-demo/config.json#/data/config/telemetry-demo/config.json#g' \
        -e 's#/var/lib/telemetry-demo#/data/db/telemetry-demo#g' \
        -e 's#/var/log/telemetry-demo#/data/log/telemetry-demo#g' \
        ${D}${systemd_system_unitdir}/telemetry-demo.service
    sed -i \
        -e 's#^ExecStart=/opt/telemetry-demo/bin/telemetry-demo[[:space:]]*$#ExecStart=/opt/telemetry-demo/bin/telemetry-demo --config /data/config/telemetry-demo/config.json#' \
        ${D}${systemd_system_unitdir}/telemetry-demo.service
    sed -i '/^StandardOutput=/d;/^StandardError=/d' \
        ${D}${systemd_system_unitdir}/telemetry-demo.service
    sed -i '/^\[Service\]/i Requires=data-layout.service\nAfter=data-layout.service' \
        ${D}${systemd_system_unitdir}/telemetry-demo.service
    sed -i '/^\[Service\]/a StandardOutput=append:/data/log/telemetry-demo/telemetry-demo.log\nStandardError=append:/data/log/telemetry-demo/telemetry-demo.log' \
        ${D}${systemd_system_unitdir}/telemetry-demo.service

    install -d ${D}${systemd_system_unitdir}/telemetry-demo.service.d
    install -m 0644 ${WORKDIR}/data-paths.conf \
        ${D}${systemd_system_unitdir}/telemetry-demo.service.d/data-paths.conf

    if [ -f ${D}${bindir}/demo-install-telemetry-binary ]; then
        sed -i \
            -e 's#/usr/bin/telemetry-demo#/opt/telemetry-demo/bin/telemetry-demo#g' \
            -e 's#/usr/bin/telemetry-demo.previous#/opt/telemetry-demo/bin/telemetry-demo.previous#g' \
            ${D}${bindir}/demo-install-telemetry-binary
    fi

    install -d ${D}${nonarch_libdir}/tmpfiles.d
    install -m 0644 ${S}/packaging/tmpfiles.d/telemetry-demo.conf ${D}${nonarch_libdir}/tmpfiles.d/telemetry-demo.conf
    sed -i 's#/var/lib/telemetry-demo#/data/db/telemetry-demo#g' \
        ${D}${nonarch_libdir}/tmpfiles.d/telemetry-demo.conf

    install -d ${D}${nonarch_libdir}/sysusers.d
    install -m 0644 ${S}/packaging/sysusers.d/telemetry-demo.conf ${D}${nonarch_libdir}/sysusers.d/telemetry-demo.conf

    install -m 0644 ${S}/config/config.example.json ${D}/opt/telemetry-demo/config.default.json
    sed -i 's#/var/lib/telemetry-demo#/data/db/telemetry-demo#g' \
        ${D}/opt/telemetry-demo/config.default.json

    if [ "${systemd_system_unitdir}" != "${prefix}/lib/systemd/system" ]; then
        rm -f ${D}${prefix}/lib/systemd/system/telemetry-demo.service
        rmdir --ignore-fail-on-non-empty ${D}${prefix}/lib/systemd/system ${D}${prefix}/lib/systemd || true
    fi
    rm -rf ${D}${sysconfdir}/telemetry-demo ${D}${prefix}/etc/telemetry-demo
    rmdir --ignore-fail-on-non-empty ${D}${prefix}/etc ${D}${sysconfdir} || true
}

FILES:${PN} += " \
    /opt/telemetry-demo \
    /opt/telemetry-demo/bin/telemetry-demo \
    /opt/telemetry-demo/config.default.json \
    ${bindir}/telemetry-demo \
    ${systemd_system_unitdir}/telemetry-demo.service \
    ${systemd_system_unitdir}/telemetry-demo.service.d/data-paths.conf \
    ${nonarch_libdir}/tmpfiles.d/telemetry-demo.conf \
    ${nonarch_libdir}/sysusers.d/telemetry-demo.conf \
"
