SUMMARY = "Small C++ telemetry service used by the Yocto demo image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=e3739cb849a7f8089d9be58707ef2e34"

inherit cmake systemd

SRC_URI = "git://github.com/SmartFlowSolution/telemetry-demo.git;protocol=https;branch=main"
SRCREV = "f8f9985b037b8badace2aa55eddabcce8139ed9f"

S = "${WORKDIR}/git"

DEPENDS += "sqlite3"

SYSTEMD_SERVICE:${PN} = "telemetry-demo.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

FILES:${PN} += " \
    ${systemd_system_unitdir}/telemetry-demo.service \
    ${nonarch_libdir}/tmpfiles.d/telemetry-demo.conf \
    ${nonarch_libdir}/sysusers.d/telemetry-demo.conf \
    ${sysconfdir}/telemetry-demo/config.json \
"
