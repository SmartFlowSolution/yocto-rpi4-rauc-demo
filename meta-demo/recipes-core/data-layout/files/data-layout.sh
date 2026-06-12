#!/bin/sh
set -eu

install -d -m 0750 -o demo -g demo /data/config

if [ ! -f /data/config/README ]; then
    cat > /data/config/README <<'EOF'
This directory is reserved for per-device provisioning data.

Example:
  /data/config/device-id

The telemetry-demo runtime config is installed by its package under:
  /etc/telemetry-demo/config.json
EOF
    chown demo:demo /data/config/README
    chmod 0640 /data/config/README
fi
