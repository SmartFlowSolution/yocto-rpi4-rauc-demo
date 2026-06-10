RAUC_DEMO_CERT_FILE ?= "${TOPDIR}/../certs/development.cert.pem"

python __anonymous() {
    import hashlib
    import os

    cert_file = d.getVar("RAUC_DEMO_CERT_FILE")
    if cert_file and os.path.exists(cert_file):
        with open(cert_file, "rb") as f:
            digest = hashlib.sha256(f.read()).hexdigest()
    else:
        digest = "missing"

    d.setVar("RAUC_DEMO_CERT_FILE_SHA256", digest)
}

do_install[vardeps] += "RAUC_DEMO_CERT_FILE_SHA256"

do_install:append() {
    if [ ! -f "${RAUC_DEMO_CERT_FILE}" ]; then
        bbfatal "Missing RAUC development certificate: ${RAUC_DEMO_CERT_FILE}. Run scripts/ensure-rauc-certs.sh before building the image."
    fi

    install -d ${D}${sysconfdir}/rauc
    install -m 0644 "${RAUC_DEMO_CERT_FILE}" ${D}${sysconfdir}/rauc/ca.cert.pem
}
