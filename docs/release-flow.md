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

## Individual steps

### Image

```bash
./scripts/build-image.sh
```

Builds `demo-image`, which produces the bootable Raspberry Pi 4 image artifacts.

### RAUC bundle

```bash
./scripts/build-rauc.sh
```

Builds the update bundle recipe. If development certificates are missing, the script creates local demo certificates under `certs/`.

### SDK

```bash
./scripts/build-sdk.sh
```

Runs `bitbake demo-image -c populate_sdk` through `kas`. The result is an SDK installer in the deploy SDK directory.

### Release packaging

```bash
./scripts/release.sh v0.1.0
```

Collects already-built image, RAUC and SDK artifacts into `release/v0.1.0/`, then writes a manifest and checksums.

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
