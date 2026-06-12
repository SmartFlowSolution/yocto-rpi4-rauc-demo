# RAUC OTA

This demo includes a RAUC-ready bundle recipe. It is intended to show the moving parts of an A/B update workflow:

- bootloader integration from the Raspberry Pi RAUC community layer,
- slot-aware rootfs image,
- bundle recipe,
- local development certificates,
- update artifact generation.

Generate local demo keys outside Git:

```bash
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout certs/development.key.pem \
  -out certs/development.cert.pem \
  -days 365 \
  -subj "/CN=Yocto Demo RAUC Development"
```

Production private keys must never be committed.
