# SSH Access

This demo image disables password login. SSH access should use public key authentication.

## Add a Key Before Build

From the repository root:

```bash
mkdir -p local-provisioning
cp ~/.ssh/id_ed25519.pub local-provisioning/demo-authorized_keys
```

`local-provisioning/` is ignored by Git, so personal keys are not committed.

Build the image:

```bash
./scripts/build-image.sh
```

If the key is added after a previous build, the image recipe tracks the key
checksum and should rebuild the root filesystem. If BitBake still reports that
nothing needs to run, force the root filesystem task once:

```bash
kas shell kas/rpi4-demo.yml -c "bitbake -f -c rootfs demo-image && bitbake demo-image"
```

The image recipe installs the public key into:

```text
/home/demo/.ssh/authorized_keys
```

## Connect to the Device

After the device boots:

```bash
ssh demo@<device-ip>
```

With an explicit private key:

```bash
ssh -i ~/.ssh/id_ed25519 demo@<device-ip>
```

## Passwordless Sudo

The image installs `sudo` and grants the `demo` account passwordless sudo access:

```sh
sudo -n true
sudo systemctl status telemetry-demo.service
```

The `demo` account has no password and should continue to use SSH key
authentication only.

## Reboot From the Demo User

For OTA testing:

```sh
sudo systemctl reboot
```

## Service and Journal Access From the Demo User

Use passwordless sudo for service administration and system journal access:

```sh
sudo systemctl status telemetry-demo.service
sudo systemctl restart telemetry-demo.service
sudo journalctl -u telemetry-demo.service -n 120 --no-pager
tail -n 120 /data/log/telemetry-demo/telemetry-demo.log
```

The application stdout and stderr are appended to the persistent file under
`/data/log`; journald contains the systemd unit lifecycle and service errors.

## Verify Target State

On the target:

```bash
export PATH=/usr/sbin:/sbin:$PATH
ls -ld /home/demo/.ssh
ls -l /home/demo/.ssh/authorized_keys
ls -l /data/config/ssh/ssh_host_*_key.pub
grep -R -i -E '^(passwordauthentication|permitrootlogin)[[:space:]]+' /etc/ssh/sshd_config /etc/ssh/sshd_config.d
grep -R -i -E '^[[:space:]]*hostkey[[:space:]]+/data/config/ssh/' /etc/ssh/sshd_config /etc/ssh/sshd_config.d
```

Expected:

```text
PasswordAuthentication no
PermitRootLogin no
HostKey /data/config/ssh/...
```

The `.ssh` directory should be owned by `demo:demo` and have restrictive permissions.
The `/data/config/ssh` host keys should remain stable across RAUC updates, so
the SSH client should not ask you to remove the target from `known_hosts` after
an update.

On this minimal image, running `sshd -T` as the unprivileged `demo` user may
print `sshd: no hostkeys available -- exiting`. That does not mean SSH login is
misconfigured; use the config-file check above or run `scripts/smoke-test.sh`
from the host.

## Security Notes

- Commit only documentation and the provisioning mechanism.
- Do not commit private keys.
- Do not commit personal public keys unless they are intentionally demo-only.
- For production, provision per-device keys outside the source repository.
