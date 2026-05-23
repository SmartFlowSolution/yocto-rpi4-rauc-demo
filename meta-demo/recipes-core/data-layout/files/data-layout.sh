#!/bin/sh
set -eu

mkdir -p /data/config
chown demo:demo /data /data/config
chmod 0750 /data/config

mkdir -p /data/config/ssh
chown root:root /data/config/ssh
chmod 0755 /data/config/ssh

mkdir -p /data/db/telemetry-demo /data/log/telemetry-demo
if [ -f /data/lib/telemetry-demo/telemetry-demo.db ] && [ ! -e /data/db/telemetry-demo/telemetry-demo.db ]; then
    mv /data/lib/telemetry-demo/telemetry-demo.db /data/db/telemetry-demo/telemetry-demo.db
fi
chown telemetry-demo:demo /data/db/telemetry-demo /data/log/telemetry-demo
chmod 0750 /data/db/telemetry-demo /data/log/telemetry-demo

mkdir -p /data/config/telemetry-demo
if [ ! -f /data/config/telemetry-demo/config.json ]; then
    cp /opt/telemetry-demo/config.default.json /data/config/telemetry-demo/config.json
else
    sed -i 's#/data/lib/telemetry-demo/telemetry-demo.db#/data/db/telemetry-demo/telemetry-demo.db#g' \
        /data/config/telemetry-demo/config.json
fi

if [ -d /data/config/telemetry-demo ]; then
    chown -R demo:demo /data/config/telemetry-demo
    chmod 0750 /data/config/telemetry-demo
    [ ! -f /data/config/telemetry-demo/config.json ] || chmod 0640 /data/config/telemetry-demo/config.json
fi

if [ ! -f /data/config/README ]; then
    cat > /data/config/README <<'EOF'
This directory is reserved for per-device provisioning data.

Example:
  /data/config/device-id
  /data/config/static-ip.conf
  /data/config/ssh/ssh_host_*_key

The telemetry-demo runtime config is installed by its package under:
  /data/config/telemetry-demo/config.json
EOF
    chown demo:demo /data/config/README
    chmod 0640 /data/config/README
fi

if [ ! -f /data/config/static-ip.conf ]; then
    cat > /data/config/static-ip.conf <<'EOF'
# Uncomment ADDRESS to switch from DHCP to static IPv4.
# INTERFACE=eth0
# ADDRESS=192.168.0.190/24
# GATEWAY=192.168.0.1
# DNS=1.1.1.1 8.8.8.8
EOF
    chown demo:demo /data/config/static-ip.conf
    chmod 0640 /data/config/static-ip.conf
fi
