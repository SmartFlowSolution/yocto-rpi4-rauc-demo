# Provisioning

This repository does not include real device credentials or endpoints.

A production project would provision:

- per-device SSH keys,
- RAUC trust material,
- VPN configuration,
- API credentials,
- device identity,
- initial runtime configuration.

For public demo purposes, VPN provisioning is represented by a no-op service
hook. Runtime configuration and persistent SSH host identity still use the real
paths described below, but no production credentials or endpoints are included.

The image prepares:

```text
/data/config
```

SSH server host keys are stored persistently under:

```text
/data/config/ssh
```

Do not delete these files during normal updates. Keeping them on `/data` means
SSH clients continue to trust the device after a RAUC rootfs update and do not
need their `known_hosts` entry removed.

The demo VPN provisioning hook is skipped unless this file exists:

```text
/data/config/device-id
```

The image can also apply an optional static IPv4 configuration from:

```text
/data/config/static-ip.conf
```

Example:

```ini
# Uncomment ADDRESS to switch from DHCP to static IPv4.
# INTERFACE=eth0
# ADDRESS=192.168.0.190/24
# GATEWAY=192.168.0.1
# DNS=1.1.1.1 8.8.8.8
```

If `ADDRESS` remains commented out, the image keeps its default DHCP behavior.
After `ADDRESS` is uncommented, `network-config.service` applies the static IPv4
configuration through `systemd-networkd`, disables DHCP for the selected
interface and writes the runtime network file under `/run/systemd/network`.
Only `ADDRESS` is required. `INTERFACE` defaults to `eth0`. Applying the change
can disconnect the current SSH session; reconnect using the configured address.

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

The image recipe tracks the checksum of `local-provisioning/demo-authorized_keys`.
Changing the key should therefore trigger the root filesystem and image tasks again.
If you added the key after a previous build and BitBake still reports that there is
nothing to do, force the root filesystem task once:

```bash
kas shell kas/rpi4-demo.yml -c "bitbake -f -c rootfs demo-image && bitbake demo-image"
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
