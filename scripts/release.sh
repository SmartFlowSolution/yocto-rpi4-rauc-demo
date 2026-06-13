#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELEASE_DIR="${REPO_DIR}/release/${VERSION}"

mkdir -p "${RELEASE_DIR}"

for file in "${RELEASE_DIR}"/*; do
  filename="${file##*/}"
  if [[ "${filename}" =~ [0-9]{14} ]]; then
    rm -f "${file}"
  fi
done

cd "${REPO_DIR}"

DEPLOY_DIR="${REPO_DIR}/build/tmp/deploy/images/raspberrypi4-64-demo"
if [ ! -d "${DEPLOY_DIR}" ] && [ -d "${REPO_DIR}/build/tmp-glibc/deploy/images/raspberrypi4-64-demo" ]; then
  DEPLOY_DIR="${REPO_DIR}/build/tmp-glibc/deploy/images/raspberrypi4-64-demo"
fi
SDK_DEPLOY_DIR="${REPO_DIR}/build/tmp/deploy/sdk"
if [ ! -d "${SDK_DEPLOY_DIR}" ] && [ -d "${REPO_DIR}/build/tmp-glibc/deploy/sdk" ]; then
  SDK_DEPLOY_DIR="${REPO_DIR}/build/tmp-glibc/deploy/sdk"
fi

if [ ! -d "${DEPLOY_DIR}" ]; then
  echo "Deploy directory not found"
  exit 1
fi

shopt -s nullglob
IMAGE_FILES=()
for file in \
  "${DEPLOY_DIR}/demo-image-raspberrypi4-64-demo.wic" \
  "${DEPLOY_DIR}/demo-image-raspberrypi4-64-demo.wic.bz2"
do
  [ ! -e "${file}" ] || IMAGE_FILES+=("${file}")
done

BMAP_FILES=()
file="${DEPLOY_DIR}/demo-image-raspberrypi4-64-demo.wic.bmap"
[ ! -e "${file}" ] || BMAP_FILES+=("${file}")

BUNDLE_FILES=()
file="${DEPLOY_DIR}/demo-update-bundle-raspberrypi4-64-demo.raucb"
[ ! -e "${file}" ] || BUNDLE_FILES+=("${file}")

SDK_FILES=()
if [ -d "${SDK_DEPLOY_DIR}" ]; then
  for file in "${SDK_DEPLOY_DIR}"/*.sh; do
    filename="${file##*/}"
    [[ "${filename}" =~ [0-9]{14} ]] || SDK_FILES+=("${file}")
  done
fi

if [ "${#IMAGE_FILES[@]}" -eq 0 ]; then
  echo "No image artifacts found in ${DEPLOY_DIR}"
  exit 1
fi

if [ "${#BUNDLE_FILES[@]}" -eq 0 ]; then
  echo "No RAUC bundle found in ${DEPLOY_DIR}"
  echo "Run scripts/build-rauc.sh first, or use scripts/full-release.sh."
  exit 1
fi

if [ "${#SDK_FILES[@]}" -eq 0 ]; then
  echo "No SDK installer found"
  echo "Run scripts/build-sdk.sh first, or use scripts/full-release.sh."
  exit 1
fi

cp -L "${IMAGE_FILES[@]}" "${RELEASE_DIR}/"
if [ "${#BMAP_FILES[@]}" -gt 0 ]; then
  cp -L "${BMAP_FILES[@]}" "${RELEASE_DIR}/"
fi
cp -L "${BUNDLE_FILES[@]}" "${RELEASE_DIR}/"
cp -L "${SDK_FILES[@]}" "${RELEASE_DIR}/"

{
  echo "{"
  echo "  \"version\": \"${VERSION}\","
  echo "  \"machine\": \"raspberrypi4-64-demo\","
  echo "  \"distro\": \"demo\","
  echo "  \"created_by\": \"scripts/release.sh\","
  echo "  \"git_commit\": \"$(git rev-parse HEAD 2>/dev/null || echo unknown)\""
  echo "}"
} > "${RELEASE_DIR}/manifest.json"

cd "${RELEASE_DIR}"
rm -f SHA256SUMS
sha256sum ./* > SHA256SUMS

echo "Release written to ${RELEASE_DIR}"
