#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <image.wic> </dev/sdX|/dev/mmcblkX|sdX|mmcblkX>"
  exit 1
fi

IMAGE="$1"
REQUESTED_DISK="$2"
DISK="${REQUESTED_DISK}"

if [[ "${DISK}" != /dev/* ]]; then
  DISK="/dev/${DISK}"
fi

if [ ! -f "${IMAGE}" ]; then
  echo "Image not found: ${IMAGE}" >&2
  exit 1
fi

if [ ! -b "${DISK}" ]; then
  echo "Block device node not found: ${DISK}" >&2
  if [ "${REQUESTED_DISK}" != "${DISK}" ]; then
    echo "Resolved '${REQUESTED_DISK}' to '${DISK}'." >&2
  fi
  if lsblk -dn -o NAME 2>/dev/null | grep -Fxq "$(basename "${DISK}")"; then
    echo >&2
    echo "The device is visible through lsblk, but ${DISK} is not available as a block device node." >&2
    echo "If you are running this script in Docker, pass the device into the container or flash from the host." >&2
    echo "Example: docker run --rm -it --device=${DISK} -v \"\$PWD:/workspace\" -w /workspace yocto-rpi4-rauc-demo bash" >&2
  fi
  lsblk
  exit 1
fi

if [ "$(lsblk -dn -o TYPE "${DISK}")" != "disk" ]; then
  echo "Target is not a whole disk: ${DISK}" >&2
  lsblk "${DISK}"
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
