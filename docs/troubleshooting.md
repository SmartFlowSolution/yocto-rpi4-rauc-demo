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

## Invalid EXTRA_USERS_PARAMS command

If `do_rootfs` fails with:

```text
Invalid command in EXTRA_USERS_PARAMS
```

check the image recipe and use commands supported by `extrausers`, for example `usermod -L user` instead of unsupported command forms.

## Missing RAUC certificates

If RAUC bundle signing fails, run:

```bash
./scripts/build-rauc.sh
```

The script creates local development certificates if they are missing. Never commit production private keys.

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
