# Provisioning

This repository does not include real device credentials or endpoints.

A production project would provision:

- per-device SSH keys,
- RAUC trust material,
- VPN configuration,
- API credentials,
- device identity,
- initial runtime configuration.

For public demo purposes, provisioning is represented by service hooks and placeholder runtime paths only.

The image prepares:

```text
/data/config
```

The demo VPN provisioning hook is skipped unless this file exists:

```text
/data/config/device-id
```

## SSH Access During Demo Builds

Password login is disabled. To access the device over SSH, inject a public key at image build time.

Create a local provisioning directory. This directory is ignored by Git:

```bash
mkdir -p local-provisioning
```

Copy your public SSH key:

```bash
cp ~/.ssh/id_ed25519.pub local-provisioning/demo-authorized_keys
```

If you use a different key:

```bash
cp ~/.ssh/<your-key>.pub local-provisioning/demo-authorized_keys
```

Then build the image:

```bash
./scripts/build-image.sh
```

or build the full release:

```bash
./scripts/full-release.sh v0.1.0
```

During `do_rootfs`, the image recipe checks:

```text
local-provisioning/demo-authorized_keys
```

If the file exists, it is installed into the target image as:

```text
/home/demo/.ssh/authorized_keys
```

with restrictive permissions.

After boot, connect from the host:

```bash
ssh demo@<device-ip>
```

or with an explicit private key:

```bash
ssh -i ~/.ssh/id_ed25519 demo@<device-ip>
```

Only the public key should be copied into `local-provisioning/demo-authorized_keys`. Never commit private keys.
