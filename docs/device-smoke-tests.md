# Device Smoke Tests

This checklist verifies the main features provided by the Yocto Raspberry Pi 4 RAUC demo image after flashing it to a device.

## Preconditions

- The image was flashed to an SD card and the Raspberry Pi 4 boots from it.
- You have access to the device through serial console or SSH with a provisioned key.
- Commands below are intended to run on the target device unless explicitly marked as host-side.
- Replace these placeholders when needed:

```bash
export TARGET_IP=192.168.1.50
export TARGET_USER=demo
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
sshd -T | grep -E 'passwordauthentication|permitrootlogin'
```

Expected:

```text
passwordauthentication no
permitrootlogin no
```

If key-based login is not configured yet, follow `docs/ssh-access.md` and rebuild the image with:

```text
local-provisioning/demo-authorized_keys
```

## 3. Installed Demo Packages and Tools

Verify the expected user-space tools are available:

```bash
command -v telemetry-demo
command -v rauc
command -v curl
command -v jq
command -v ip
command -v iptables
```

Expected:

- every command prints a path,
- `telemetry-demo` resolves to `/usr/bin/telemetry-demo`.

Check the telemetry binary:

```bash
telemetry-demo --interview-easter-egg
```

Expected:

- output includes `telemetry-demo interview easter egg`,
- output includes RAII, stack/heap and type layout sections.

## 4. telemetry-demo Service

Check service installation:

```bash
systemctl cat telemetry-demo.service
systemctl is-enabled telemetry-demo.service
```

Expected:

```text
enabled
```

Start the service:

```bash
systemctl restart telemetry-demo.service
systemctl status telemetry-demo.service --no-pager
```

Expected:

- service exits successfully because it is a `Type=oneshot` demo service,
- status should be `inactive (dead)` after a successful run or show a successful completed oneshot,
- there should be no crash or permission error.

Inspect logs:

```bash
journalctl -u telemetry-demo.service -n 80 --no-pager
```

Expected:

- logs show sensor collection,
- logs show dry-run HTTP publishing,
- no stack trace or unhandled exception appears.

## 5. telemetry-demo Filesystem Layout

Verify installed files:

```bash
ls -l /usr/bin/telemetry-demo
ls -l /etc/telemetry-demo/config.json
ls -ld /var/lib/telemetry-demo
```

Expected:

- binary exists under `/usr/bin`,
- config exists under `/etc/telemetry-demo`,
- runtime directory exists under `/var/lib/telemetry-demo`.

Verify config content:

```bash
jq . /etc/telemetry-demo/config.json
```

Expected:

- valid JSON,
- `database_path` points under `/var/lib/telemetry-demo`,
- `publisher_dry_run` is `true`.

Verify runtime output after service run:

```bash
ls -l /var/lib/telemetry-demo
```

Expected:

- SQLite database file exists after `telemetry-demo.service` runs,
- ownership is compatible with the `telemetry-demo` service user.

## 6. Manual telemetry-demo Run

Run the service manually with the packaged config:

```bash
runuser -u telemetry-demo -- telemetry-demo --config /etc/telemetry-demo/config.json
```

If `runuser` is unavailable, use:

```bash
su -s /bin/sh -c 'telemetry-demo --config /etc/telemetry-demo/config.json' telemetry-demo
```

Expected:

- command completes successfully,
- dry-run payload is printed,
- `/var/lib/telemetry-demo/telemetry-demo.db` is created or updated.

## 7. Health Endpoint Check

The default config runs one iteration, so the health endpoint may exist only briefly. For a longer manual health check, create a temporary config:

```bash
cp /etc/telemetry-demo/config.json /tmp/telemetry-demo-health.json
jq '.iterations = 0 | .interval_seconds = 2 | .health_enabled = true | .health_port = 8080' \
  /etc/telemetry-demo/config.json > /tmp/telemetry-demo-health.json
```

Start the process:

```bash
runuser -u telemetry-demo -- telemetry-demo --config /tmp/telemetry-demo-health.json &
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

## 8. Provisioning Placeholder

Verify `/data/config` exists:

```bash
ls -ld /data/config
cat /data/config/README
```

Expected:

- directory exists,
- README explains that `/data/config/device-id` is a placeholder for per-device provisioning.

Check VPN provisioning hook state:

```bash
systemctl status vpn-provisioning.service --no-pager
```

Expected:

- service is skipped or inactive if `/data/config/device-id` does not exist,
- no real endpoint is contacted.

Optional provisioning hook test:

```bash
echo demo-device-001 > /data/config/device-id
systemctl start vpn-provisioning.service
journalctl -u vpn-provisioning.service -n 40 --no-pager
rm -f /data/config/device-id
```

Expected:

- journal says this is a demo provisioning hook,
- no private endpoint or credential is used.

## 9. Firewall and Sysctl Baseline

Check firewall service:

```bash
systemctl status firewall.service --no-pager
iptables -S
```

Expected:

- firewall service is active or successfully completed,
- default `INPUT` policy is `DROP`,
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
- `rauc status` runs without missing-command errors.

If the current board setup does not include full bootloader slot metadata yet, document the exact `rauc status` output as a known demo limitation.

## 12. Journal Review

Review recent boot logs:

```bash
journalctl -b -p warning --no-pager
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
- runtime state lands under `/var/lib/telemetry-demo`,
- `/data/config` exists only as a provisioning placeholder,
- firewall and sysctl baseline are active,
- RAUC command-line tooling is present,
- no private credentials, domains or product-specific behavior are visible.
