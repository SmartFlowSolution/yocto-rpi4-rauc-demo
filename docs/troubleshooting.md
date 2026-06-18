# Troubleshooting

Yocto builds are sensitive to disk space, network availability and small recipe mistakes. This document lists common failures and the first things to check.

## Disk space

Check available space:

```bash
df -h .
du -h -d 2 build
```

The most common large directories are:

```text
build/tmp-glibc
build/downloads
build/sstate-cache
build/cache
```

Recommended cleanup order:

```bash
rm -rf build/tmp-glibc
rm -rf build/cache
```

Avoid deleting `build/sstate-cache` unless you really need the space. It contains reusable task outputs and makes the next build much faster.

Avoid deleting `build/downloads` unless necessary. Without it, Yocto must download source archives again.

## BitBake inotify `No space left on device`

If parsing fails in `pyinotify` with `add_watch` and `ENOSPC`, first distinguish
an inotify limit from actual disk exhaustion:

```bash
df -h .
df -i .
sysctl -n fs.inotify.max_user_watches
sysctl -n fs.inotify.max_user_instances
```

When disk space and inodes are available, raise the host limits:

```bash
sudo sysctl -w fs.inotify.max_user_watches=524288
sudo sysctl -w fs.inotify.max_user_instances=1024
```

For a persistent host setting:

```bash
printf '%s\n' \
  'fs.inotify.max_user_watches=524288' \
  'fs.inotify.max_user_instances=1024' \
  | sudo tee /etc/sysctl.d/99-yocto-inotify.conf
sudo sysctl --system
```

These commands must run on the Docker host because the container uses the host
kernel's inotify limits. Restart the failed build afterward; BitBake cleanup is
not required for this error.

## Invalid EXTRA_USERS_PARAMS command

If `do_rootfs` fails with:

```text
Invalid command in EXTRA_USERS_PARAMS
```

check the image recipe and use commands supported by `extrausers`, for example `usermod -L user` instead of unsupported command forms.

## Missing RAUC certificates

If RAUC bundle signing fails, run:

```bash
./scripts/ensure-rauc-certs.sh
./scripts/build-rauc.sh
```

The helper creates local development certificates if they are missing. Never commit production private keys.

## RAUC install fails with self-signed certificate

If `rauc install` fails with:

```text
signature verification failed: Verify error: self-signed certificate
```

the running image does not trust the certificate used to sign the bundle. Rebuild
and flash an image that was built from the same `certs/development.cert.pem` as
the bundle:

```bash
./scripts/build-image.sh
./scripts/build-rauc.sh
```

On the target, the trusted demo certificate should be installed at:

```text
/etc/rauc/ca.cert.pem
```

## Smoke test reports `data-config-dir` failed

If `scripts/smoke-test.sh demo@<device-ip>` reports:

```text
FAIL data-config-dir /data/config missing; data-layout.service likely failed
```

check the target service:

```bash
systemctl status data-layout.service --no-pager
systemctl cat data-layout.service
```

The current image expects `/data` to mount read-write before `data-layout.service`
runs. If `/data` is not mounted, inspect `/etc/fstab`, `findmnt /data`, and the
kernel log for filesystem errors. Older images may still contain a
`data-layout.sh` that uses the `install` command at runtime. Rebuild and flash a
current image:

```bash
./scripts/full-release.sh v0.1.0
./scripts/flash.sh release/v0.1.0/demo-image-raspberrypi4-64-demo.wic /dev/mmcblk0
```

The current service prepares `/data/config`, `/data/db/telemetry-demo` and
`/data/log/telemetry-demo` during boot.

## `sshd -T` says no hostkeys available

When run as the unprivileged `demo` user, this command may print:

```text
sshd: no hostkeys available -- exiting.
```

Use the config-file check instead:

```bash
grep -R -i -E '^(passwordauthentication|permitrootlogin)[[:space:]]+' /etc/ssh/sshd_config /etc/ssh/sshd_config.d
```

or run the host-side smoke test:

```bash
./scripts/smoke-test.sh demo@<device-ip>
```

## Network fetch failures

After `build/downloads` is removed, the next build needs network access again. Retry transient failures first. If a source URL is permanently gone, pinning mirrors or using a shared downloads directory is usually the next step.

## Full rebuild after cleanup

If `tmp-glibc`, `downloads` and `sstate-cache` were removed, the next build is effectively a clean build:

```text
fetch -> unpack -> configure -> compile -> package -> rootfs -> image
```

This is expected. Once the build completes, `downloads` and `sstate-cache` will be repopulated.

## Where to inspect logs

BitBake task logs are under:

```text
build/tmp-glibc/work/<machine>-demo-oe-linux/<recipe>/<version>/temp/
```

Useful files:

```text
log.do_compile
log.do_install
log.do_rootfs
run.do_rootfs.*
```

The exact path is usually printed in the BitBake error message.
