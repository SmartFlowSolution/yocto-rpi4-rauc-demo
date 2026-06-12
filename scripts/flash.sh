#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <image.wic> </dev/sdX|/dev/mmcblkX>"
  exit 1
fi

IMAGE="$1"
DISK="$2"

if [ ! -f "${IMAGE}" ]; then
  echo "Image not found: ${IMAGE}" >&2
  exit 1
fi

if [ ! -b "${DISK}" ]; then
  echo "Block device not found: ${DISK}" >&2
  lsblk
  exit 1
fi

echo "Target disk:"
lsblk "${DISK}"
echo
read -r -p "All data on ${DISK} will be overwritten. Type FLASH to continue: " CONFIRM

if [ "${CONFIRM}" != "FLASH" ]; then
  echo "Aborted."
  exit 0
fi

sudo umount "${DISK}"* 2>/dev/null || true

if command -v bmaptool >/dev/null 2>&1 && [ -f "${IMAGE}.bmap" ]; then
  sudo bmaptool copy "${IMAGE}" "${DISK}"
else
  sudo dd if="${IMAGE}" of="${DISK}" bs=4M status=progress conv=fsync
fi

sync
sudo eject "${DISK}" || true
echo "Done."
