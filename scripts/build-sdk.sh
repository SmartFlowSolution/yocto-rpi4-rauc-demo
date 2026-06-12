#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
KAS_FILE="${REPO_DIR}/kas/rpi4-demo.yml"

cd "${REPO_DIR}"
kas shell "${KAS_FILE}" -c "bitbake demo-image -c populate_sdk"
