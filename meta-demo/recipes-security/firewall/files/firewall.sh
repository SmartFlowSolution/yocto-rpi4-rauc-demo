#!/bin/sh
set -eu

IPT=iptables

$IPT -F
$IPT -t nat -F
$IPT -t mangle -F
$IPT -X

$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT

$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

$IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
$IPT -A INPUT -p icmp -j ACCEPT

# SSH is intended for lab/demo networks only. Production devices should use
# per-device keys and stricter source restrictions.
$IPT -A INPUT -p tcp --dport 22 -j ACCEPT

exit 0
