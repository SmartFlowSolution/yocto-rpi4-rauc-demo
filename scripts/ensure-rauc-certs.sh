#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CERT_DIR="${REPO_DIR}/certs"

mkdir -p "${CERT_DIR}"

if [ ! -f "${CERT_DIR}/development.key.pem" ] || [ ! -f "${CERT_DIR}/development.cert.pem" ]; then
  openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout "${CERT_DIR}/development.key.pem" \
    -out "${CERT_DIR}/development.cert.pem" \
    -days 365 \
    -subj "/CN=Yocto Demo RAUC Development"
fi
