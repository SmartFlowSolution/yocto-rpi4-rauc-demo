#!/bin/sh
set -eu

DEVICE_ID="$(cat /data/config/device-id)"

if [ -z "${DEVICE_ID}" ]; then
    echo "device-id is empty"
    exit 1
fi

echo "Demo provisioning hook for device ${DEVICE_ID}"
echo "No real endpoint is contacted in this public repository."
