# Architecture

The demo image is built from a custom Yocto layer named `meta-demo`.

Main components:

- `demo-image`: target image recipe.
- `telemetry-demo`: C++ telemetry service fetched from Git by the BitBake recipe, packaged with CMake and installed under `/opt/telemetry-demo`.
- `data-layout`: prepares persistent configuration, database and log directories under `/data`.
- `firewall-hardening`: installs firewall and sysctl baseline.
- `ssh hardening`: disables root login and password authentication.
- `linux-raspberrypi` fragments: enables TUN and netfilter features.
- `demo-update-bundle`: RAUC bundle recipe for OTA updates.

The `telemetry-demo` package installs its own systemd service, runtime config under `/data/config/telemetry-demo`, runtime state under `/data/db/telemetry-demo` and persistent service logs under `/data/log/telemetry-demo`.

`network-config` translates the optional `/data/config/static-ip.conf` into a
high-priority runtime `systemd-networkd` configuration. DHCP remains enabled when
no active `ADDRESS` is present.

The design mirrors a common embedded Linux product structure while keeping all product logic mocked.
