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

## Verify Target State

On the target:

```bash
ls -ld /home/demo/.ssh
ls -l /home/demo/.ssh/authorized_keys
sshd -T | grep -E 'passwordauthentication|permitrootlogin'
```

Expected:

```text
passwordauthentication no
permitrootlogin no
```

The `.ssh` directory should be owned by `demo:demo` and have restrictive permissions.

## Security Notes

- Commit only documentation and the provisioning mechanism.
- Do not commit private keys.
- Do not commit personal public keys unless they are intentionally demo-only.
- For production, provision per-device keys outside the source repository.
