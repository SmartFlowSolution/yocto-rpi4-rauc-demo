# Yocto Raspberry Pi 4 RAUC Demo

Sanitized Yocto Project demo for Raspberry Pi 4. The repository shows a practical embedded Linux workflow without product-specific code, domains, credentials or private infrastructure.

## What This Demonstrates

- Custom Yocto layer structure.
- Custom distro, machine and image recipes.
- Raspberry Pi 4 64-bit target.
- systemd-based image.
- RAUC-ready A/B OTA update flow.
- C++ `telemetry-demo` service built with CMake and BitBake.
- Application under `/opt/telemetry-demo`, runtime configuration under `/data/config/telemetry-demo`, runtime state under `/data/db/telemetry-demo` and persistent service logs under `/data/log/telemetry-demo`.
- Read-only `/` and `/home` mounts, with `/boot` and `/data` writable.
- Optional static IP template in `/data/config/static-ip.conf`; DHCP remains the default until `ADDRESS` is uncommented.
- Persistent SSH host identity under `/data/config/ssh`, so RAUC updates do not trigger client `known_hosts` churn.
- Passwordless `sudo` access for the `demo` user during lab administration.
- SSH, firewall and sysctl hardening examples.
- Kernel config fragments for TUN and netfilter.
- Reproducible build setup with `kas`.
- Release manifest and checksums.

## Repository Layout

```text
yocto-rpi4-rauc-demo/
├── kas/rpi4-demo.yml
├── scripts/
│   ├── build-image.sh
│   ├── build-rauc.sh
│   ├── build-sdk.sh
│   ├── build.sh
│   ├── update-telemetry-demo-srcrev.sh
│   ├── full-release.sh
│   ├── release.sh
│   ├── flash.sh
│   └── smoke-test.sh
├── meta-demo/
│   ├── conf/
│   ├── recipes-core/
│   ├── recipes-connectivity/
│   ├── recipes-demo/
│   ├── recipes-kernel/
│   └── recipes-security/
└── docs/
```

## Quick Start

The recommended path is to build inside the included Docker environment. Yocto has a large host dependency set, and the container keeps the demo reproducible without preparing the workstation first.

```bash
docker build -t yocto-rpi4-rauc-demo .
```

Build all main artifacts: image, RAUC bundle and SDK installer:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  -w /workspace \
  yocto-rpi4-rauc-demo \
  ./scripts/full-release.sh v0.1.0
```

Run the full release in Docker with a CPU limit, useful on a workstation where Yocto should not consume all CPU time:

```bash
docker run --rm --cpus=0.5 \
  -v "$PWD:/workspace" \
  -w /workspace \
  yocto-rpi4-rauc-demo \
  ./scripts/full-release.sh v0.1.0
```

For faster local iteration in the same container image, build only one target:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  -w /workspace \
  yocto-rpi4-rauc-demo \
  ./scripts/build-image.sh
```

To run several commands in one session, start an interactive shell inside the same container image:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  -w /workspace \
  yocto-rpi4-rauc-demo \
  bash

./scripts/full-release.sh v0.1.0
./scripts/build-image.sh
./scripts/build-rauc.sh
./scripts/build-sdk.sh
```

Package already-built artifacts into `release/<version>`:

```bash
./scripts/release.sh v0.1.0
```

Compatibility wrapper:

```bash
./scripts/build.sh image
./scripts/build.sh rauc
./scripts/build.sh sdk
./scripts/build.sh all
```

Update the pinned `telemetry-demo` application revision used by the BitBake recipe:

```bash
./scripts/update-telemetry-demo-srcrev.sh
git diff -- meta-demo/recipes-demo/telemetry-demo/telemetry-demo.bb
```

Flash an SD card:

```bash
./scripts/flash.sh build/tmp/deploy/images/raspberrypi4-64-demo/demo-image-raspberrypi4-64-demo.wic /dev/sdX
```

If flashing from inside Docker, start the container with the target block device passed through:

```bash
docker run --rm -it \
  --device=/dev/sdX \
  -v "$PWD:/workspace" \
  -w /workspace \
  yocto-rpi4-rauc-demo \
  bash

./scripts/flash.sh release/v0.1.0/demo-image-raspberrypi4-64-demo.wic /dev/sdX
```

Replace `/dev/sdX` with the whole SD-card device shown by `lsblk`, for example `/dev/mmcblk0`. Do not use a partition such as `/dev/sdX1` or `/dev/mmcblk0p1`.

Run smoke tests against a booted device:

```bash
./scripts/smoke-test.sh demo@<device-ip>
```

The smoke-test script is the recommended first pass after flashing. It reports
`PASS`, `WARN`, `SKIP` and `FAIL`, and uses passwordless sudo when available for
the `demo` user. It also compares the target SSH provisioning file and RAUC
certificate with the current checkout by SHA-256. See
`docs/device-smoke-tests.md` for the manual checklist.

## Security Notes

This demo intentionally avoids default passwords. SSH password login is disabled and root login is disabled. Production devices should be provisioned with per-device SSH keys, credentials and certificates outside the source repository.

The `demo` account has unrestricted passwordless sudo for lab convenience. This
is not an appropriate production authorization policy.

The RAUC bundle recipe expects locally generated demo certificates. See `docs/rauc-ota.md` for the certificate setup steps. Do not commit production private keys.

The demo image installs the local development RAUC certificate as
`/etc/rauc/ca.cert.pem`. Rebuild and flash the image whenever
`certs/development.cert.pem` changes, then build bundles with the matching key
and certificate.

The CI workflow includes a simple guardrail that checks for common secret, credential and private-artifact patterns before changes are pushed further.

## What Is Mocked

The included `telemetry-demo` service is fetched by its BitBake recipe from `https://github.com/SmartFlowSolution/telemetry-demo.git` through a pinned `SRCREV`. It contains demo application logic and shows C++ application packaging, systemd integration, runtime paths and image composition.

## LinkedIn-Friendly Summary

This project is a cleaned-up embedded Linux demo based on a real Yocto workflow. It focuses on the engineering parts that matter in production systems: reproducible builds, custom layers, OTA update structure, systemd integration, device hardening and release artifacts.

## Documentation

- `docs/architecture.md`
- `docs/build-artifacts.md`
- `docs/release-flow.md`
- `docs/device-smoke-tests.md`
- `docs/troubleshooting.md`
- `docs/what-was-sanitized.md`
- `docs/rauc-ota.md`
- `docs/security.md`
- `docs/provisioning.md`
- `docs/ssh-access.md`
