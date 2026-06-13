#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DISTRO_CONF="${REPO_DIR}/meta-demo/conf/distro/demo.conf"
DISTRO_VERSION="${VERSION#v}"

if [[ ! "${DISTRO_VERSION}" =~ ^[A-Za-z0-9][A-Za-z0-9._+~-]*$ ]]; then
  echo "Invalid release version: ${VERSION}" >&2
  exit 1
fi

if ! grep -q '^DISTRO_VERSION[[:space:]]*=' "${DISTRO_CONF}"; then
  echo "DISTRO_VERSION not found in ${DISTRO_CONF}" >&2
  exit 1
fi

sed -i "s/^DISTRO_VERSION[[:space:]]*=.*/DISTRO_VERSION = \"${DISTRO_VERSION}\"/" "${DISTRO_CONF}"
echo "Building release ${VERSION} with DISTRO_VERSION=${DISTRO_VERSION}"

"${SCRIPT_DIR}/build-image.sh"
"${SCRIPT_DIR}/build-rauc.sh"
"${SCRIPT_DIR}/build-sdk.sh"
"${SCRIPT_DIR}/release.sh" "${VERSION}"
