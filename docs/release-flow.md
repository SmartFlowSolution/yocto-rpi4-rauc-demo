# Release Flow

The release flow is intentionally split into small scripts. This keeps local iteration fast and makes the final release process explicit.

## Flow

```text
build-image.sh
      |
      v
build-rauc.sh
      |
      v
build-sdk.sh
      |
      v
release.sh <version>
```

The convenience entry point is:

```bash
./scripts/full-release.sh v0.1.0
```

Before building, the script sets `DISTRO_VERSION = "0.1.0"` in
`meta-demo/conf/distro/demo.conf` from the release argument. A leading `v` is
kept in the release directory name and omitted from `DISTRO_VERSION`.

## Individual steps

### Image

```bash
./scripts/build-image.sh
```

Cleans and builds `demo-image`, which produces the bootable Raspberry Pi 4 image artifacts.

### RAUC bundle

```bash
./scripts/build-rauc.sh
```

Cleans and builds the update bundle recipe. If development certificates are missing, the script creates local demo certificates under `certs/`. The image build uses the same local certificate as the target RAUC trust keyring, so rebuild and flash the image after changing `certs/development.cert.pem`.

### SDK

```bash
./scripts/build-sdk.sh
```

Cleans `demo-image`, then runs `bitbake demo-image -c populate_sdk` through
`kas`. The result is an SDK installer in the deploy SDK directory.

### Release packaging

```bash
./scripts/release.sh v0.1.0
```

Collects already-built image, RAUC and SDK artifacts into `release/v0.1.0/`, then writes a manifest and checksums.
Only stable deploy aliases without Yocto build timestamps are copied; dated
artifact variants remain in the build deploy directories. Existing timestamped
files in the selected release directory are removed, and deploy symlinks are
dereferenced so the release contains regular files.

## Docker with CPU limit

For a workstation build that should not consume all CPU time:

```bash
docker run --rm --cpus=0.5 \
  -v "$PWD:/workspace" \
  -w /workspace \
  yocto-rpi4-rauc-demo \
  ./scripts/full-release.sh v0.1.0
```

`--cpus=0.5` limits the container to roughly half of one CPU core. This is slower, but keeps the machine responsive.

## What this demonstrates

- repeatable Yocto build orchestration,
- separation between build and packaging,
- OTA bundle generation,
- SDK generation,
- release checksums and artifact manifest,
- practical shell automation around BitBake.
