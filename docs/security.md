# Security Baseline

This demo intentionally starts from a safer default than many development images:

- no default user passwords,
- SSH password authentication disabled,
- root SSH login disabled,
- application runs as a dedicated system user,
- systemd hardening options enabled for the demo service,
- firewall and sysctl baseline installed,
- runtime state isolated under `/var/lib/telemetry-demo`.

Production systems should add secure boot, signed OTA, per-device provisioning, log redaction, vulnerability scanning and a key rotation process.
