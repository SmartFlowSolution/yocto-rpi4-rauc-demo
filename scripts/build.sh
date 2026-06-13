#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/build.sh [all|image|rauc|bundle|sdk]

Targets:
  all     Build image, RAUC bundle and SDK installer (default)
  image   Build only demo-image
  rauc    Build only the RAUC update bundle
  bundle  Alias for rauc
  sdk     Build only the SDK installer for demo-image

Notes:
  - SDK builds are intentionally slower and are usually better suited for
    release/nightly jobs than quick edit-compile loops.
  - The image and bundle targets create local development RAUC certificates when missing.
EOF
}

TARGET="${1:-all}"

if [ "$#" -gt 1 ]; then
  usage
  exit 1
fi

case "${TARGET}" in
  all)
    "${SCRIPT_DIR}/build-image.sh"
    "${SCRIPT_DIR}/build-rauc.sh"
    "${SCRIPT_DIR}/build-sdk.sh"
    ;;
  image)
    "${SCRIPT_DIR}/build-image.sh"
    ;;
  rauc|bundle)
    "${SCRIPT_DIR}/build-rauc.sh"
    ;;
  sdk)
    "${SCRIPT_DIR}/build-sdk.sh"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
