# Architecture

The demo image is built from a custom Yocto layer named `meta-demo`.

Main components:

- `demo-image`: target image recipe.
- `telemetry-demo`: C++ telemetry service fetched from Git by the BitBake recipe and packaged with CMake.
- `data-layout`: prepares `/data/config` for optional per-device provisioning placeholders.
- `firewall-hardening`: installs firewall and sysctl baseline.
- `ssh hardening`: disables root login and password authentication.
- `linux-raspberrypi` fragments: enables TUN and netfilter features.
- `demo-update-bundle`: RAUC bundle recipe for OTA updates.

The `telemetry-demo` package installs its own systemd service, runtime config under `/etc/telemetry-demo` and tmpfiles/sysusers definitions for `/var/lib/telemetry-demo`.

The design mirrors a common embedded Linux product structure while keeping all product logic mocked.
