#!/bin/sh
set -eu

CONFIG=/data/config/static-ip.conf

if [ ! -f "${CONFIG}" ]; then
    echo "${CONFIG} not found; keeping default network configuration"
    exit 0
fi

INTERFACE=eth0
ADDRESS=
GATEWAY=
DNS=

while IFS= read -r line || [ -n "${line}" ]; do
    line="${line%%#*}"

    case "${line}" in
        *=*) ;;
        *) continue ;;
    esac

    key="${line%%=*}"
    value="${line#*=}"
    key="$(printf '%s' "${key}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    value="$(printf '%s' "${value}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    case "${key}" in
        INTERFACE) INTERFACE="${value}" ;;
        ADDRESS) ADDRESS="${value}" ;;
        GATEWAY) GATEWAY="${value}" ;;
        DNS) DNS="${value}" ;;
        "") ;;
        *) echo "Ignoring unknown static IP key: ${key}" ;;
    esac
done < "${CONFIG}"

if [ -z "${ADDRESS}" ]; then
    echo "No active ADDRESS in ${CONFIG}; keeping default DHCP network configuration"
    exit 0
fi

case "${INTERFACE}" in
    ""|*[!A-Za-z0-9_.:-]*)
        echo "Invalid INTERFACE in ${CONFIG}: ${INTERFACE}"
        exit 1
        ;;
esac

tries=0
while ! ip link show dev "${INTERFACE}" >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "${tries}" -ge 15 ]; then
        echo "Network interface ${INTERFACE} not found"
        exit 1
    fi
    sleep 1
done

mkdir -p /run/systemd/network
{
    echo "# Generated from ${CONFIG}"
    echo "[Match]"
    echo "Name=${INTERFACE}"
    echo
    echo "[Network]"
    echo "DHCP=no"
    echo "Address=${ADDRESS}"
    [ -z "${GATEWAY}" ] || echo "Gateway=${GATEWAY}"
    [ -z "${DNS}" ] || echo "DNS=${DNS}"
} > /run/systemd/network/10-demo-static.network

networkctl reload
networkctl reconfigure "${INTERFACE}"

echo "Applied static IP ${ADDRESS} on ${INTERFACE}"
