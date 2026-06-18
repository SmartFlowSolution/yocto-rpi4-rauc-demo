# Build Artifacts

This document explains what the build produces and where to look for the important files.

## Main image

Build command:

```bash
./scripts/build-image.sh
```

Expected deploy directory:

```text
build/tmp-glibc/deploy/images/raspberrypi4-64-demo/
```

Important files:

```text
demo-image-raspberrypi4-64-demo.wic
demo-image-raspberrypi4-64-demo.wic.bz2
demo-image-raspberrypi4-64-demo.wic.bmap
demo-image-raspberrypi4-64-demo.ext4
demo-image-raspberrypi4-64-demo.tar.bz2
```

The `.wic` image is the SD-card image. The `.bmap` file can be used with `bmaptool` for faster and safer flashing.

## RAUC bundle

Build command:

```bash
./scripts/build-rauc.sh
```

Stable deploy name:

```text
build/tmp-glibc/deploy/images/raspberrypi4-64-demo/demo-update-bundle-raspberrypi4-64-demo.raucb
```

The `.raucb` file is the signed update bundle. This demo uses development certificates from `certs/`; the image installs `certs/development.cert.pem` as `/etc/rauc/ca.cert.pem`, and the bundle is signed with the matching certificate and key. Production certificates should be generated and stored outside the source repository.

## SDK installer

Build command:

```bash
./scripts/build-sdk.sh
```

Expected deploy directory:

```text
build/tmp-glibc/deploy/sdk/
```

Expected file pattern:

```text
*.sh
```

The SDK installer contains the cross-toolchain and target sysroot needed to build external applications against the image environment.

## Release package

Build and package everything:

```bash
./scripts/full-release.sh v0.1.0
```

Package already-built artifacts:

```bash
./scripts/release.sh v0.1.0
```

Expected release directory:

```text
release/v0.1.0/
```

Expected release content:

```text
demo-image-raspberrypi4-64-demo.wic
demo-image-raspberrypi4-64-demo.wic.bz2
demo-image-raspberrypi4-64-demo.wic.bmap
demo-update-bundle-raspberrypi4-64-demo.raucb
*.sh
manifest.json
SHA256SUMS
```

`release.sh` follows the stable Yocto deploy aliases and copies them as regular
files. Timestamped build variants are not copied. `manifest.json` records the
release version, machine, distro and Git commit. `SHA256SUMS` verifies the copied
artifacts and manifest.
