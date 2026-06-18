# Device Smoke Tests

This checklist verifies the main features provided by the Yocto Raspberry Pi 4 RAUC demo image after flashing it to a device.

## Automated Smoke Test

The fastest way to check a freshly flashed device is the host-side smoke-test
script:

```bash
./scripts/smoke-test.sh demo@<device-ip>
```

With an explicit SSH key:

```bash
./scripts/smoke-test.sh demo@<device-ip> -i ~/.ssh/id_ed25519
```

Result meanings:

- `PASS`: the check matched the expected state.
- `WARN`: the state is usable but worth inspecting.
- `SKIP`: the check needs root, passwordless sudo, or journal permissions that the current target login does not have.
- `FAIL`: the image or target state does not match the expected demo behavior.

When logged in as `demo`, the stock image should provide passwordless sudo, so
privileged checks should run. Any `SKIP` entries are worth reviewing.

The script calculates SHA-256 values from the host-side
`local-provisioning/demo-authorized_keys` and `certs/development.cert.pem`, then
compares them with the files installed on the target. Run it from the same
checkout that was used to build the image.

## Preconditions

- The image was flashed to an SD card and the Raspberry Pi 4 boots from it.
- You have access to the device through serial console or SSH with a provisioned key.
- Commands below are intended to run on the target device unless explicitly marked as host-side.
- Log in as `demo` for SSH access checks and non-privileged binary/config checks.
- Commands that restart services, read the full system journal, write under `/data`, or inspect firewall/sysctl state require a privileged target shell. The stock demo image grants `demo` passwordless sudo access.
- Replace these placeholders when needed:

```bash
export TARGET_IP=<device-ip>
export TARGET_USER=demo
export PATH=/usr/sbin:/sbin:$PATH
```

Password login is intentionally disabled in this demo image. Do not expect root or `demo` password login to work.

## 1. Boot and Basic System Identity

Check that the system booted with systemd:

```bash
systemctl is-system-running
```

Expected:

```text
running
```

`degraded` is acceptable only while investigating a known failed optional service. Check details with:

```bash
systemctl --failed
```

Check OS information:

```bash
cat /etc/os-release
uname -a
hostnamectl
```

Expected:

- the system identifies as the demo Yocto image/distro,
- kernel reports the Raspberry Pi target,
- no unexpected hostname or private product branding appears.

Verify read-only and writable mounts:

```bash
findmnt -no OPTIONS /
findmnt -no OPTIONS /boot
findmnt -no OPTIONS /home
findmnt -no OPTIONS /data
```

Expected:

- `/` and `/home` include `ro`,
- `/boot` and `/data` include `rw`.

## 2. SSH Hardening

From the host, verify SSH is reachable only with key-based access:

```bash
ssh "${TARGET_USER}@${TARGET_IP}" true
```

Expected:

```text
command exits with status 0
```

Verify password authentication is disabled:

```bash
grep -R -i -E '^(passwordauthentication|permitrootlogin)[[:space:]]+' /etc/ssh/sshd_config /etc/ssh/sshd_config.d
grep -R -i -E '^[[:space:]]*hostkey[[:space:]]+/data/config/ssh/' /etc/ssh/sshd_config /etc/ssh/sshd_config.d
ls -l /data/config/ssh/ssh_host_*_key.pub
```

Expected:

```text
PasswordAuthentication no
PermitRootLogin no
HostKey /data/config/ssh/...
```

The SSH host keys should live under `/data/config/ssh` so RAUC rootfs updates do
not change the server identity seen by SSH clients.

`sshd -T` may require host keys that are not readable to the unprivileged
`demo` user. The smoke-test script falls back to checking the readable config
files when that happens.

If key-based login is not configured yet, follow `docs/ssh-access.md` and rebuild the image with:

```text
local-provisioning/demo-authorized_keys
```

## 3. Installed Demo Packages and Tools

Verify the expected user-space tools are available:

```bash
ls -l /opt/telemetry-demo/bin/telemetry-demo
command -v telemetry-demo
command -v rauc
command -v curl
command -v jq
command -v nano
command -v sqlite3
command -v ip
command -v iptables
getent group telemetry-demo
```

Expected:

- every command succeeds,
- `telemetry-demo` binary exists under `/opt/telemetry-demo/bin/telemetry-demo`,
- `telemetry-demo` wrapper is available in `PATH`,
- `telemetry-demo` group exists for the systemd service.

Check the telemetry binary:

```bash
/opt/telemetry-demo/bin/telemetry-demo --interview-easter-egg
```

Expected:

- output includes `telemetry-demo interview easter egg`,
- output includes RAII, stack/heap and type layout sections.

## 4. telemetry-demo Service

Check service installation:

```bash
sudo systemctl cat telemetry-demo.service
sudo systemctl is-enabled telemetry-demo.service
```

Expected:

```text
enabled
```

Start the service:

```bash
sudo systemctl restart telemetry-demo.service
sudo systemctl status telemetry-demo.service
```

Expected:

- service exits successfully because it is a `Type=oneshot` demo service,
- status should be `inactive (dead)` after a successful run or show a successful completed oneshot,
- there should be no crash or permission error.

The stock image grants the `demo` user passwordless sudo for these lab checks.

Inspect logs:

```bash
sudo journalctl -u telemetry-demo.service -n 80 --no-pager
tail -n 80 /data/log/telemetry-demo/telemetry-demo.log
```

Expected:

- journald shows the systemd unit lifecycle,
- the persistent log shows sensor collection and dry-run HTTP publishing,
- no stack trace or unhandled exception appears.

## 5. telemetry-demo Filesystem Layout

Verify installed files:

```bash
ls -l /opt/telemetry-demo/bin/telemetry-demo
ls -l /data/config/telemetry-demo/config.json
ls -ld /data/db/telemetry-demo
ls -ld /data/log/telemetry-demo
```

Expected:

- binary exists under `/opt/telemetry-demo/bin`,
- config exists under `/data/config/telemetry-demo`,
- runtime directory exists under `/data/db/telemetry-demo`,
- persistent log directory exists under `/data/log/telemetry-demo`.

Verify config content:

```bash
jq . /data/config/telemetry-demo/config.json
```

Expected:

- valid JSON,
- `database_path` points under `/data/db/telemetry-demo`,
- `publisher_dry_run` is `true`.

Verify runtime output after service run:

```bash
ls -l /data/db/telemetry-demo
ls -l /data/log/telemetry-demo
```

Expected:

- SQLite database file exists after `telemetry-demo.service` runs,
- `/data/log/telemetry-demo/telemetry-demo.log` exists after `telemetry-demo.service` writes output,
- the log file grows after the automated smoke test restarts the service,
- ownership is compatible with the `telemetry-demo` service user.

The runtime directory may not be readable by the unprivileged `demo` user.

## 6. Manual telemetry-demo Run

This section uses sudo to switch to the locked `telemetry-demo` service user.

Run the service manually with the packaged config:

```bash
sudo -u telemetry-demo /opt/telemetry-demo/bin/telemetry-demo --config /data/config/telemetry-demo/config.json
```

Alternatively, from a root shell use:

```bash
runuser -u telemetry-demo -- /opt/telemetry-demo/bin/telemetry-demo --config /data/config/telemetry-demo/config.json
```

Expected:

- command completes successfully,
- dry-run payload is printed,
- `/data/db/telemetry-demo/telemetry-demo.db` is created or updated.

## 7. Health Endpoint Check

This section uses sudo because it starts the process as the locked
`telemetry-demo` service user.

The default config runs one iteration, so the health endpoint may exist only briefly. For a longer manual health check, create a temporary config:

```bash
cp /data/config/telemetry-demo/config.json /tmp/telemetry-demo-health.json
jq '.iterations = 0 | .interval_seconds = 2 | .health_enabled = true | .health_port = 8080' \
  /data/config/telemetry-demo/config.json > /tmp/telemetry-demo-health.json
```

Start the process:

```bash
sudo -u telemetry-demo /opt/telemetry-demo/bin/telemetry-demo --config /tmp/telemetry-demo-health.json &
echo $! > /tmp/telemetry-demo-health.pid
sleep 2
```

Query health:

```bash
curl -s http://127.0.0.1:8080/health | jq .
```

Expected:

```json
{
  "status": "ok"
}
```

The exact counters may vary, but `collected_metrics`, `published_metrics` and `dropped_batches` fields should be present.

Stop the manual process:

```bash
kill "$(cat /tmp/telemetry-demo-health.pid)"
rm -f /tmp/telemetry-demo-health.pid /tmp/telemetry-demo-health.json
```

## 8. Provisioning and Network Configuration

Verify `/data/config` exists:

```bash
ls -ld /data/config
cat /data/config/README
```

Expected:

- directory exists,
- README identifies `/data/config/device-id` as a provisioning placeholder and documents the optional static IP configuration.

Check optional static IP provisioning state:

```bash
systemctl status network-config.service --no-pager
```

Expected:

- service is active or successfully completed with the commented template,
- DHCP remains active until `ADDRESS` is uncommented.

Optional static IP config format:

```ini
# Uncomment ADDRESS to switch from DHCP to static IPv4.
# INTERFACE=eth0
# ADDRESS=192.168.0.190/24
# GATEWAY=192.168.0.1
# DNS=1.1.1.1 8.8.8.8
```

Check VPN provisioning hook state:

```bash
systemctl status vpn-provisioning.service --no-pager
```

Expected:

- service is skipped or inactive if `/data/config/device-id` does not exist,
- the automated smoke test creates a temporary `device-id` when needed, restarts
  the service, verifies its exit status and journal message, then removes the
  temporary file,
- no real endpoint is contacted.

Optional provisioning hook test:

```bash
echo demo-device-001 > /data/config/device-id
sudo systemctl start vpn-provisioning.service
sudo journalctl -u vpn-provisioning.service -n 40 --no-pager
rm -f /data/config/device-id
```

Expected:

- journal says this is a demo provisioning hook,
- no private endpoint or credential is used.

The optional provisioning hook test requires a privileged target shell.

## 9. Firewall and Sysctl Baseline

This section requires a privileged target shell. Also ensure `/usr/sbin` and
`/sbin` are in `PATH` when checking tools installed outside the regular user path.

Check firewall service:

```bash
sudo systemctl status firewall.service --no-pager
sudo iptables -S
```

Expected:

- firewall service is active or successfully completed,
- default `INPUT` and `FORWARD` policies are `DROP`, while `OUTPUT` is `ACCEPT`,
- loopback, established traffic, ICMP and SSH rules are present.

Check sysctl hardening values:

```bash
sysctl net.ipv4.ip_forward
sysctl net.ipv4.conf.all.accept_redirects
sysctl net.ipv4.conf.all.send_redirects
sysctl net.ipv4.conf.all.accept_source_route
sysctl kernel.kptr_restrict
sysctl kernel.dmesg_restrict
```

Expected:

```text
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
```

## 10. Kernel Features

Verify TUN support:

```bash
ls -l /dev/net/tun
```

Expected:

- `/dev/net/tun` exists.

Verify basic network state:

```bash
ip addr
ip route
```

Expected:

- at least one network interface is up,
- device has an expected IP address or a clear reason why it is offline.

## 11. RAUC Availability

Check RAUC is installed:

```bash
rauc --version
rauc status
```

Expected:

- `rauc --version` prints the installed RAUC version,
- `rauc status` runs without missing-command errors,
- `/etc/rauc/system.conf` selects `/etc/rauc/ca.cert.pem`,
- the installed certificate SHA-256 matches `certs/development.cert.pem` from
  the build checkout.

If the current board setup does not include full bootloader slot metadata yet, document the exact `rauc status` output as a known demo limitation.

After installing an update, reboot with:

```bash
sudo systemctl reboot
```

## 12. Journal Review

Review recent boot logs:

```bash
sudo journalctl -u telemetry-demo.service -n 120 --no-pager
sudo journalctl -u firewall.service -n 120 --no-pager
tail -n 120 /data/log/telemetry-demo/telemetry-demo.log
```

Expected:

- no repeated service crash loop,
- no missing binary for `telemetry-demo`,
- no missing systemd unit referenced by another service,
- no private domain, credential or product endpoint appears.

## 13. Final Pass Criteria

The image passes smoke testing when:

- the device boots,
- SSH hardening is applied,
- `telemetry-demo` is installed and runs successfully,
- runtime state lands under `/data/db/telemetry-demo`,
- telemetry service logs land under `/data/log/telemetry-demo`,
- `/data/config` contains the expected persistent runtime and provisioning configuration,
- firewall and sysctl baseline are active,
- RAUC command-line tooling is present,
- no private credentials, domains or product-specific behavior are visible.
