#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/smoke-test.sh <user@host> [ssh-options...]

Examples:
  scripts/smoke-test.sh demo@<device-ip>
  scripts/smoke-test.sh demo@<device-ip> -i ~/.ssh/id_ed25519

The script runs target-side checks over SSH. Privileged checks are run only when
the SSH user is root or has passwordless sudo. Otherwise they are reported as
SKIP/WARN so an unprivileged demo login does not look like a broken image.
EOF
}

if [ "$#" -lt 1 ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

TARGET="$1"
shift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

file_sha256_or_missing() {
  local path="$1"
  if [ -f "${path}" ]; then
    sha256sum "${path}" | awk '{print $1}'
  else
    echo missing
  fi
}

EXPECTED_AUTHORIZED_KEYS_SHA256="$(file_sha256_or_missing "${REPO_DIR}/local-provisioning/demo-authorized_keys")"
EXPECTED_RAUC_CERT_SHA256="$(file_sha256_or_missing "${REPO_DIR}/certs/development.cert.pem")"

SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=10
)

echo "== Yocto RPi4 RAUC demo smoke test =="
echo "Target: ${TARGET}"
echo

ssh "${SSH_OPTS[@]}" "$@" "${TARGET}" sh -s -- \
  "${EXPECTED_AUTHORIZED_KEYS_SHA256}" "${EXPECTED_RAUC_CERT_SHA256}" <<'TARGET_SMOKE_TEST'
EXPECTED_AUTHORIZED_KEYS_SHA256="${1:-missing}"
EXPECTED_RAUC_CERT_SHA256="${2:-missing}"

PATH=/usr/sbin:/sbin:/usr/bin:/bin
export PATH

TELEMETRY_BIN=/opt/telemetry-demo/bin/telemetry-demo
TELEMETRY_CONFIG=/data/config/telemetry-demo/config.json
TELEMETRY_STATE_DIR=/data/db/telemetry-demo
TELEMETRY_LOG_DIR=/data/log/telemetry-demo
TELEMETRY_LOG=${TELEMETRY_LOG_DIR}/telemetry-demo.log

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf 'PASS %-30s %s\n' "$1" "$2"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf 'WARN %-30s %s\n' "$1" "$2"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'FAIL %-30s %s\n' "$1" "$2"
}

skip() {
    SKIP_COUNT=$((SKIP_COUNT + 1))
    printf 'SKIP %-30s %s\n' "$1" "$2"
}

section() {
    echo
    echo "## $1"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

ssh_config_text() {
    for path in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do
        [ -r "${path}" ] && cat "${path}"
    done
}

check_cmd() {
    if have "$1"; then
        pass "command:$1" "$(command -v "$1")"
    else
        fail "command:$1" "not found in PATH=${PATH}"
    fi
}

mount_opts() {
    awk -v mountpoint="$1" '$2 == mountpoint { print $4; found = 1 } END { if (!found) exit 1 }' /proc/mounts
}

check_mount_mode() {
    mountpoint="$1"
    expected="$2"

    if opts="$(mount_opts "${mountpoint}")"; then
        case ",${opts}," in
            *",${expected},"*)
                pass "mount:${mountpoint}" "${expected}"
                ;;
            *)
                fail "mount:${mountpoint}" "expected ${expected}, got ${opts}"
                ;;
        esac
    else
        fail "mount:${mountpoint}" "not mounted"
    fi
}

run_priv() {
    if [ "${PRIVILEGED}" = "root" ]; then
        "$@"
    elif [ "${PRIVILEGED}" = "sudo" ]; then
        sudo "$@"
    else
        return 126
    fi
}

read_unit_journal() {
    unit="$1"
    lines="${2:-80}"

    if [ "${PRIVILEGED}" != "none" ]; then
        run_priv journalctl -u "${unit}" -n "${lines}" --no-pager --quiet
    elif have demo-journalctl; then
        demo-journalctl "${unit}" "${lines}"
    else
        return 126
    fi
}

if [ "$(id -u)" = "0" ]; then
    PRIVILEGED=root
elif have sudo && sudo -n true >/dev/null 2>&1; then
    PRIVILEGED=sudo
else
    PRIVILEGED=none
fi

section "Identity"

USER_NAME="$(id -un 2>/dev/null || echo unknown)"
HOST_NAME="$(hostname 2>/dev/null || echo unknown)"
pass "login" "${USER_NAME}@${HOST_NAME}"

RUNNING="$(systemctl is-system-running 2>/dev/null || true)"
case "${RUNNING}" in
    running)
        pass "system-state" "${RUNNING}"
        ;;
    degraded)
        warn "system-state" "degraded"
        systemctl --failed --no-pager 2>/dev/null || true
        ;;
    "")
        fail "system-state" "systemctl is-system-running returned no output"
        ;;
    *)
        fail "system-state" "${RUNNING}"
        ;;
esac

if [ -r /etc/os-release ]; then
    OS_RELEASE="$(cat /etc/os-release)"
    echo "${OS_RELEASE}" | grep -q '^ID=demo$' \
        && pass "os-release:id" "ID=demo" \
        || fail "os-release:id" "expected ID=demo"
    echo "${OS_RELEASE}" | grep -q 'Yocto RPi4 RAUC Demo' \
        && pass "os-release:name" "demo image detected" \
        || warn "os-release:name" "expected demo pretty name not found"
else
    fail "os-release" "/etc/os-release is not readable"
fi

UNAME="$(uname -a 2>/dev/null || true)"
echo "${UNAME}" | grep -q 'aarch64' \
    && pass "kernel-arch" "${UNAME}" \
    || fail "kernel-arch" "${UNAME:-uname failed}"

section "SSH"

if have sshd; then
    SSHD_CONFIG="$(sshd -T 2>/dev/null || true)"
    if [ -z "${SSHD_CONFIG}" ]; then
        SSHD_CONFIG="$(ssh_config_text | sed 's/#.*//' | tr '[:upper:]' '[:lower:]')"
        SSHD_SOURCE="config files"
    else
        SSHD_SOURCE="sshd -T"
    fi

    echo "${SSHD_CONFIG}" | grep -Eq '^[[:space:]]*passwordauthentication[[:space:]]+no([[:space:]]|$)' \
        && pass "ssh-password-auth" "disabled (${SSHD_SOURCE})" \
        || fail "ssh-password-auth" "expected passwordauthentication no"
    echo "${SSHD_CONFIG}" | grep -Eq '^[[:space:]]*permitrootlogin[[:space:]]+no([[:space:]]|$)' \
        && pass "ssh-root-login" "disabled (${SSHD_SOURCE})" \
        || fail "ssh-root-login" "expected permitrootlogin no"
    echo "${SSHD_CONFIG}" | grep -Eq '^[[:space:]]*hostkey[[:space:]]+/data/config/ssh/ssh_host_ed25519_key([[:space:]]|$)' \
        && pass "ssh-hostkeys-config" "/data/config/ssh" \
        || fail "ssh-hostkeys-config" "expected HostKey entries under /data/config/ssh"
else
    fail "sshd" "sshd not found; PATH=${PATH}"
fi

for key_type in rsa ecdsa ed25519; do
    key="/data/config/ssh/ssh_host_${key_type}_key"
    [ -s "${key}" ] \
        && pass "ssh-hostkey:${key_type}" "${key}" \
        || fail "ssh-hostkey:${key_type}" "missing ${key}"
    [ -s "${key}.pub" ] \
        && pass "ssh-hostkey-pub:${key_type}" "${key}.pub" \
        || fail "ssh-hostkey-pub:${key_type}" "missing ${key}.pub"

    if [ -s "${key}" ] && [ -s "${key}.pub" ] && have ssh-keygen; then
        if run_priv ssh-keygen -lf "${key}" >/tmp/ssh-hostkey-private-fp.out 2>/dev/null; then
            private_fp="$(awk 'NR == 1 { print $2 }' /tmp/ssh-hostkey-private-fp.out)"
            public_fp="$(ssh-keygen -lf "${key}.pub" 2>/dev/null | awk 'NR == 1 { print $2 }')"
            if [ -n "${private_fp}" ] && [ "${private_fp}" = "${public_fp}" ]; then
                pass "ssh-hostkey-sha:${key_type}" "${public_fp}"
            else
                fail "ssh-hostkey-sha:${key_type}" "private/public fingerprints differ"
            fi
        elif [ "${PRIVILEGED}" = "none" ]; then
            skip "ssh-hostkey-sha:${key_type}" "private key requires root or passwordless sudo"
        else
            fail "ssh-hostkey-sha:${key_type}" "could not calculate private key fingerprint"
        fi
        rm -f /tmp/ssh-hostkey-private-fp.out
    fi
done

AUTHORIZED_KEYS=/home/demo/.ssh/authorized_keys
if [ -r "${AUTHORIZED_KEYS}" ]; then
    pass "authorized-keys" "${AUTHORIZED_KEYS}"

    if [ "${EXPECTED_AUTHORIZED_KEYS_SHA256}" = "missing" ]; then
        skip "authorized-keys-sha256" "local provisioning file was absent when the test started"
    else
        actual_sha="$(sha256sum "${AUTHORIZED_KEYS}" | awk '{print $1}')"
        if [ "${actual_sha}" = "${EXPECTED_AUTHORIZED_KEYS_SHA256}" ]; then
            pass "authorized-keys-sha256" "${actual_sha}"
        else
            fail "authorized-keys-sha256" "expected ${EXPECTED_AUTHORIZED_KEYS_SHA256}, got ${actual_sha}"
        fi
    fi
else
    warn "authorized-keys" "${AUTHORIZED_KEYS} not readable for ${USER_NAME}"
fi

section "Mounts"

check_mount_mode / ro
check_mount_mode /boot rw
check_mount_mode /home ro
check_mount_mode /data rw

section "telemetry-demo"

TELEMETRY_LOG_SIZE_BEFORE=0
if [ -f "${TELEMETRY_LOG}" ]; then
    TELEMETRY_LOG_SIZE_BEFORE="$(wc -c < "${TELEMETRY_LOG}" 2>/dev/null || echo 0)"
fi
TELEMETRY_RESTARTED=no

if "${TELEMETRY_BIN}" --interview-easter-egg >/tmp/telemetry-demo-easter.out 2>&1; then
    grep -q 'telemetry-demo interview easter egg' /tmp/telemetry-demo-easter.out \
        && pass "telemetry-binary" "easter egg output OK" \
        || fail "telemetry-binary" "unexpected output"
else
    fail "telemetry-binary" "${TELEMETRY_BIN} --interview-easter-egg failed"
fi
rm -f /tmp/telemetry-demo-easter.out

systemctl is-enabled telemetry-demo.service >/tmp/telemetry-demo-enabled.out 2>/dev/null \
    && pass "telemetry-enabled" "$(cat /tmp/telemetry-demo-enabled.out)" \
    || fail "telemetry-enabled" "not enabled or not installed"
rm -f /tmp/telemetry-demo-enabled.out

if run_priv systemctl restart telemetry-demo.service >/tmp/telemetry-restart.out 2>&1; then
    pass "telemetry-restart" "service restart accepted"
    TELEMETRY_RESTARTED=yes
elif have demo-systemctl && demo-systemctl restart telemetry-demo.service >/tmp/telemetry-restart.out 2>&1; then
    pass "telemetry-restart" "demo-systemctl restart accepted"
    TELEMETRY_RESTARTED=yes
elif [ "${PRIVILEGED}" = "none" ]; then
    skip "telemetry-restart" "requires root, passwordless sudo, or demo-systemctl"
else
    fail "telemetry-restart" "$(cat /tmp/telemetry-restart.out)"
fi
rm -f /tmp/telemetry-restart.out

if [ "${TELEMETRY_RESTARTED}" = "yes" ]; then
    sleep 2
fi

STATUS="$(systemctl is-active telemetry-demo.service 2>/dev/null || true)"
case "${STATUS}" in
    inactive|active)
        pass "telemetry-active-state" "${STATUS}"
        ;;
    failed)
        fail "telemetry-active-state" "failed"
        systemctl status telemetry-demo.service --no-pager 2>/dev/null || true
        ;;
    *)
        warn "telemetry-active-state" "${STATUS:-unknown}"
        ;;
esac

[ -x "${TELEMETRY_BIN}" ] \
    && pass "telemetry-bin-path" "${TELEMETRY_BIN}" \
    || fail "telemetry-bin-path" "missing or not executable"

[ -r "${TELEMETRY_CONFIG}" ] \
    && pass "telemetry-config" "${TELEMETRY_CONFIG}" \
    || fail "telemetry-config" "missing or not readable"

if jq -e '.database_path == "/data/db/telemetry-demo/telemetry-demo.db" and .publisher_dry_run == true' "${TELEMETRY_CONFIG}" >/dev/null 2>&1; then
    pass "telemetry-config-json" "database path and dry-run OK"
else
    fail "telemetry-config-json" "unexpected config content"
fi

if [ -d "${TELEMETRY_STATE_DIR}" ]; then
    pass "telemetry-state-dir" "${TELEMETRY_STATE_DIR} exists"
    if ls "${TELEMETRY_STATE_DIR}" >/dev/null 2>&1; then
        pass "telemetry-state-readable" "readable by ${USER_NAME}"
    else
        warn "telemetry-state-readable" "not readable by ${USER_NAME}; expected for locked-down service data"
    fi
else
    fail "telemetry-state-dir" "${TELEMETRY_STATE_DIR} missing"
fi

[ -d "${TELEMETRY_LOG_DIR}" ] \
    && pass "telemetry-log-dir" "${TELEMETRY_LOG_DIR}" \
    || fail "telemetry-log-dir" "missing"

if systemctl cat telemetry-demo.service 2>/dev/null | grep -Fqx "StandardOutput=append:${TELEMETRY_LOG}"; then
    pass "telemetry-log-config" "append:${TELEMETRY_LOG}"
else
    fail "telemetry-log-config" "expected StandardOutput=append:${TELEMETRY_LOG}"
fi

if [ -s "${TELEMETRY_LOG}" ]; then
    TELEMETRY_LOG_SIZE_AFTER="$(wc -c < "${TELEMETRY_LOG}" 2>/dev/null || echo 0)"
    pass "telemetry-log-file" "${TELEMETRY_LOG} (${TELEMETRY_LOG_SIZE_AFTER} bytes)"

    if [ "${TELEMETRY_RESTARTED}" != "yes" ]; then
        skip "telemetry-log-append" "service was not restarted by this test"
    elif [ "${TELEMETRY_LOG_SIZE_AFTER}" -gt "${TELEMETRY_LOG_SIZE_BEFORE}" ]; then
        pass "telemetry-log-append" "grew from ${TELEMETRY_LOG_SIZE_BEFORE} to ${TELEMETRY_LOG_SIZE_AFTER} bytes"
    else
        fail "telemetry-log-append" "did not grow after restart (${TELEMETRY_LOG_SIZE_AFTER} bytes)"
    fi
else
    fail "telemetry-log-file" "missing or empty after service restart"
fi

section "Provisioning"

if [ -d /data/config ]; then
    pass "data-config-dir" "/data/config exists"
else
    fail "data-config-dir" "/data/config missing; data-layout.service likely failed"
fi

if [ -r /data/config/README ]; then
    grep -q '/data/config/device-id' /data/config/README \
        && pass "data-config-readme" "placeholder documented" \
        || warn "data-config-readme" "README does not mention device-id"
    grep -q '/data/config/static-ip.conf' /data/config/README \
        && pass "data-config-static-ip-readme" "static IP placeholder documented" \
        || warn "data-config-static-ip-readme" "README does not mention static-ip.conf"
else
    warn "data-config-readme" "not readable by ${USER_NAME}"
fi

NETWORK_CONFIG_STATE="$(systemctl is-active network-config.service 2>/dev/null || true)"
case "${NETWORK_CONFIG_STATE}" in
    inactive|active)
        pass "network-config-state" "${NETWORK_CONFIG_STATE}"
        ;;
    failed)
        fail "network-config-state" "failed"
        ;;
    *)
        warn "network-config-state" "${NETWORK_CONFIG_STATE:-unknown}"
        ;;
esac

systemctl is-enabled vpn-provisioning.service >/tmp/vpn-enabled.out 2>&1 \
    && pass "vpn-provisioning-enabled" "$(cat /tmp/vpn-enabled.out)" \
    || fail "vpn-provisioning-enabled" "not enabled or not installed"
rm -f /tmp/vpn-enabled.out

[ -x /usr/libexec/demo/vpn-provisioning.sh ] \
    && pass "vpn-provisioning-script" "executable" \
    || fail "vpn-provisioning-script" "missing or not executable"

VPN_DEVICE_ID_CREATED=no
if [ ! -e /data/config/device-id ]; then
    if printf '%s\n' smoke-test-device > /data/config/device-id 2>/dev/null; then
        VPN_DEVICE_ID_CREATED=yes
        pass "vpn-provisioning-fixture" "temporary device-id created"
    elif run_priv sh -c "printf '%s\\n' smoke-test-device > /data/config/device-id" 2>/dev/null; then
        VPN_DEVICE_ID_CREATED=yes
        pass "vpn-provisioning-fixture" "temporary device-id created with privileges"
    else
        skip "vpn-provisioning-fixture" "could not create temporary device-id"
    fi
fi

if [ -s /data/config/device-id ]; then
    VPN_EXECUTED=no
    if run_priv systemctl restart vpn-provisioning.service >/tmp/vpn-restart.out 2>&1; then
        pass "vpn-provisioning-run" "service executed"
        VPN_EXECUTED=yes
    elif have demo-systemctl && demo-systemctl restart vpn-provisioning.service >/tmp/vpn-restart.out 2>&1; then
        pass "vpn-provisioning-run" "service executed via demo-systemctl"
        VPN_EXECUTED=yes
    elif [ "${PRIVILEGED}" = "none" ]; then
        skip "vpn-provisioning-run" "requires root, passwordless sudo, or demo-systemctl"
    else
        fail "vpn-provisioning-run" "$(cat /tmp/vpn-restart.out)"
    fi

    if [ "${VPN_EXECUTED}" = "yes" ]; then
        VPN_RESULT="$(systemctl show vpn-provisioning.service -p Result --value 2>/dev/null || true)"
        VPN_EXIT_STATUS="$(systemctl show vpn-provisioning.service -p ExecMainStatus --value 2>/dev/null || true)"
        if [ "${VPN_RESULT}" = "success" ] && [ "${VPN_EXIT_STATUS}" = "0" ]; then
            pass "vpn-provisioning-result" "Result=success, ExecMainStatus=0"
        else
            fail "vpn-provisioning-result" "Result=${VPN_RESULT:-unknown}, ExecMainStatus=${VPN_EXIT_STATUS:-unknown}"
        fi
    else
        skip "vpn-provisioning-result" "service was not executed by this test"
    fi

    if [ "${VPN_EXECUTED}" != "yes" ]; then
        skip "vpn-provisioning-journal" "service was not executed by this test"
    elif read_unit_journal vpn-provisioning.service 40 >/tmp/vpn-journal.out 2>&1; then
        grep -q 'Demo provisioning hook for device' /tmp/vpn-journal.out \
            && pass "vpn-provisioning-journal" "provisioning hook message present" \
            || fail "vpn-provisioning-journal" "expected hook message not found"
    else
        skip "vpn-provisioning-journal" "journal access unavailable"
    fi
    rm -f /tmp/vpn-restart.out /tmp/vpn-journal.out
else
    skip "vpn-provisioning-run" "/data/config/device-id is missing or empty"
    skip "vpn-provisioning-result" "service condition was not satisfied"
    skip "vpn-provisioning-journal" "service condition was not satisfied"
fi

if [ "${VPN_DEVICE_ID_CREATED}" = "yes" ]; then
    if rm -f /data/config/device-id 2>/dev/null || run_priv rm -f /data/config/device-id 2>/dev/null; then
        pass "vpn-provisioning-cleanup" "temporary device-id removed"
    else
        fail "vpn-provisioning-cleanup" "could not remove temporary /data/config/device-id"
    fi
fi

VPN_STATE="$(systemctl is-active vpn-provisioning.service 2>/dev/null || true)"
case "${VPN_STATE}" in
    inactive|active)
        pass "vpn-provisioning-state" "${VPN_STATE}"
        ;;
    failed)
        fail "vpn-provisioning-state" "failed"
        ;;
    *)
        warn "vpn-provisioning-state" "${VPN_STATE:-unknown}"
        ;;
esac

section "Firewall and Sysctl"

systemctl is-enabled firewall.service >/tmp/firewall-enabled.out 2>&1 \
    && pass "firewall-enabled" "$(cat /tmp/firewall-enabled.out)" \
    || fail "firewall-enabled" "not enabled or not installed"
rm -f /tmp/firewall-enabled.out

FIREWALL_STATE="$(systemctl is-active firewall.service 2>/dev/null || true)"
case "${FIREWALL_STATE}" in
    active)
        pass "firewall-service" "active"
        ;;
    inactive)
        warn "firewall-service" "inactive"
        ;;
    failed)
        fail "firewall-service" "failed"
        ;;
    *)
        warn "firewall-service" "${FIREWALL_STATE:-unknown}"
        ;;
esac

if run_priv iptables -S >/tmp/iptables.out 2>&1; then
    grep -q '^-P INPUT DROP' /tmp/iptables.out \
        && pass "iptables-input-policy" "DROP" \
        || fail "iptables-input-policy" "expected INPUT DROP"
    grep -q '^-P FORWARD DROP' /tmp/iptables.out \
        && pass "iptables-forward-policy" "DROP" \
        || fail "iptables-forward-policy" "expected FORWARD DROP"
    grep -q '^-P OUTPUT ACCEPT' /tmp/iptables.out \
        && pass "iptables-output-policy" "ACCEPT" \
        || fail "iptables-output-policy" "expected OUTPUT ACCEPT"

    run_priv iptables -C INPUT -i lo -j ACCEPT >/dev/null 2>&1 \
        && pass "iptables-loopback" "INPUT loopback accepted" \
        || fail "iptables-loopback" "expected loopback ACCEPT rule"
    run_priv iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT >/dev/null 2>&1 \
        && pass "iptables-established" "ESTABLISHED,RELATED accepted" \
        || fail "iptables-established" "expected conntrack ACCEPT rule"
    run_priv iptables -C INPUT -p icmp -j ACCEPT >/dev/null 2>&1 \
        && pass "iptables-icmp" "ICMP accepted" \
        || fail "iptables-icmp" "expected ICMP ACCEPT rule"
    run_priv iptables -C INPUT -p tcp --dport 22 -j ACCEPT >/dev/null 2>&1 \
        && pass "iptables-ssh" "tcp/22 accepted" \
        || fail "iptables-ssh" "expected tcp/22 ACCEPT rule"
else
    if [ "${PRIVILEGED}" = "none" ]; then
        skip "iptables" "requires root or passwordless sudo"
    else
        fail "iptables" "$(cat /tmp/iptables.out)"
    fi
fi
rm -f /tmp/iptables.out

for item in \
    'net.ipv4.ip_forward=0' \
    'net.ipv4.conf.all.accept_redirects=0' \
    'net.ipv4.conf.all.send_redirects=0' \
    'net.ipv4.conf.all.accept_source_route=0' \
    'kernel.kptr_restrict=2' \
    'kernel.dmesg_restrict=1'
do
    key="${item%%=*}"
    expected="${item#*=}"
    value="$(sysctl -n "${key}" 2>/dev/null || true)"
    if [ "${value}" = "${expected}" ]; then
        pass "sysctl:${key}" "${value}"
    elif [ -z "${value}" ]; then
        fail "sysctl:${key}" "could not read"
    else
        fail "sysctl:${key}" "expected ${expected}, got ${value}"
    fi
done

section "Kernel and Network"

[ -c /dev/net/tun ] \
    && pass "tun-device" "/dev/net/tun" \
    || fail "tun-device" "/dev/net/tun missing"

ip addr show >/tmp/ip-addr.out 2>&1 \
    && pass "ip-addr" "ip addr works" \
    || fail "ip-addr" "$(cat /tmp/ip-addr.out)"
rm -f /tmp/ip-addr.out

ip route show >/tmp/ip-route.out 2>&1 \
    && pass "ip-route" "ip route works" \
    || fail "ip-route" "$(cat /tmp/ip-route.out)"
rm -f /tmp/ip-route.out

section "RAUC"

rauc --version >/tmp/rauc-version.out 2>&1 \
    && pass "rauc-version" "$(head -n 1 /tmp/rauc-version.out)" \
    || fail "rauc-version" "$(cat /tmp/rauc-version.out)"
rm -f /tmp/rauc-version.out

if [ -r /etc/rauc/system.conf ]; then
    grep -Eq '^[[:space:]]*path[[:space:]]*=[[:space:]]*/etc/rauc/ca\.cert\.pem[[:space:]]*$' /etc/rauc/system.conf \
        && pass "rauc-keyring-config" "/etc/rauc/ca.cert.pem" \
        || fail "rauc-keyring-config" "expected keyring path in /etc/rauc/system.conf"
else
    fail "rauc-system-config" "/etc/rauc/system.conf is not readable"
fi

if [ -s /etc/rauc/ca.cert.pem ]; then
    if [ "${EXPECTED_RAUC_CERT_SHA256}" = "missing" ]; then
        skip "rauc-cert-sha256" "local development certificate was absent when the test started"
    else
        actual_sha="$(sha256sum /etc/rauc/ca.cert.pem | awk '{print $1}')"
        if [ "${actual_sha}" = "${EXPECTED_RAUC_CERT_SHA256}" ]; then
            pass "rauc-cert-sha256" "${actual_sha}"
        else
            fail "rauc-cert-sha256" "expected ${EXPECTED_RAUC_CERT_SHA256}, got ${actual_sha}"
        fi
    fi
else
    fail "rauc-cert" "/etc/rauc/ca.cert.pem is missing or empty"
fi

if rauc status >/tmp/rauc-status.out 2>&1; then
    pass "rauc-status" "status command succeeded"
else
    warn "rauc-status" "$(head -n 1 /tmp/rauc-status.out)"
fi
rm -f /tmp/rauc-status.out

section "Journal"

if read_unit_journal telemetry-demo.service 40 >/tmp/telemetry-journal.out 2>&1; then
    if [ -s /tmp/telemetry-journal.out ] && ! grep -q '^-- No entries --$' /tmp/telemetry-journal.out; then
        pass "journal:telemetry-demo" "unit lifecycle entries present"
    else
        fail "journal:telemetry-demo" "journal is readable but contains no unit entries"
    fi
elif [ "${PRIVILEGED}" = "none" ]; then
    skip "journal:telemetry-demo" "requires journal access or demo-journalctl"
else
    fail "journal:telemetry-demo" "$(cat /tmp/telemetry-journal.out)"
fi
rm -f /tmp/telemetry-journal.out

if run_priv journalctl -b -p warning --no-pager --quiet >/tmp/journal-warning.out 2>&1; then
    if [ -s /tmp/journal-warning.out ]; then
        warn "journal-warnings" "warnings present; inspect target logs"
        head -n 40 /tmp/journal-warning.out
    else
        pass "journal-warnings" "no warning-or-higher boot logs"
    fi
elif have demo-journalctl && demo-journalctl firewall.service 120 >/tmp/journal-warning.out 2>&1; then
    pass "journal:firewall" "demo-journalctl readable"
elif [ "${PRIVILEGED}" = "none" ]; then
    skip "journal-warnings" "requires root, passwordless sudo, journal group access, or demo-journalctl"
else
    fail "journal-warnings" "$(cat /tmp/journal-warning.out)"
fi
rm -f /tmp/journal-warning.out

echo
echo "== Summary =="
echo "PASS=${PASS_COUNT} WARN=${WARN_COUNT} SKIP=${SKIP_COUNT} FAIL=${FAIL_COUNT}"

if [ "${FAIL_COUNT}" -gt 0 ]; then
    exit 1
fi

exit 0
TARGET_SMOKE_TEST
