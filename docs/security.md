# Security Baseline

This demo intentionally starts from a safer default than many development images:

- no default user passwords,
- SSH password authentication disabled,
- root SSH login disabled,
- application runs as a dedicated system user,
- systemd hardening options enabled for the demo service,
- firewall and sysctl baseline installed,
- runtime state isolated under `/data/db/telemetry-demo`,
- read-only `/` and `/home` mounts, with `/boot` and `/data` writable.

The `demo` account has unrestricted passwordless sudo for lab use. Production
systems should replace that policy and add secure boot, protected production OTA
signing keys, per-device provisioning, log redaction, vulnerability scanning and
a key rotation process.
