# RAUC OTA

This demo includes a RAUC-ready bundle recipe. It is intended to show the moving parts of an A/B update workflow:

- bootloader integration from the Raspberry Pi RAUC community layer,
- slot-aware rootfs image,
- bundle recipe,
- local development certificates,
- update artifact generation.

Generate local demo keys outside Git:

```bash
./scripts/ensure-rauc-certs.sh
```

Production private keys must never be committed.

The image installs `certs/development.cert.pem` as `/etc/rauc/ca.cert.pem`.
The bundle recipe signs updates with the matching `certs/development.key.pem`
and `certs/development.cert.pem`. The image and bundle must be rebuilt from the
same `certs/` directory; otherwise the target will reject the bundle during
signature verification.

The image and bundle recipes track the checksum of the local development
certificate, and the bundle recipe also tracks the checksum of the private key.
Changing files under `certs/` should rebuild the affected artifacts. If BitBake
still reuses an older result from a previous build, force the affected tasks
once:

```bash
kas shell kas/rpi4-demo.yml -c "bitbake -f -c install rauc && bitbake demo-image"
kas shell kas/rpi4-demo.yml -c "bitbake -f -c bundle demo-update-bundle && bitbake demo-update-bundle"
```

The host-side smoke test compares the SHA-256 of
`certs/development.cert.pem` with `/etc/rauc/ca.cert.pem` on the target and also
checks that `/etc/rauc/system.conf` selects that keyring.
