#!/bin/bash
# VPSForge v1.0.0 — Network info and public IP detection.

# ── Global Network State ─────────────────────────────────────────────────────
INCUS_CIDR=""
INCUS_GATEWAY=""
INCUS_NETMASK=""
IP_START=100
PUBLIC_IP=""

# ── Network Info ─────────────────────────────────────────────────────────────

get_network_info() {
  INCUS_CIDR=$(incus network get incusbr0 ipv4.address 2>/dev/null || true)
  [ -n "$INCUS_CIDR" ] && [ "$INCUS_CIDR" != "none" ] || { echo "incusbr0 has no IPv4."; exit 1; }
  INCUS_GATEWAY="${INCUS_CIDR%/*}"
  INCUS_NETMASK="${INCUS_CIDR#*/}"
  IFS='.' read -r A B C D <<< "$INCUS_GATEWAY"
  NETWORK_PREFIX="$A.$B.$C"
}

get_public_ip() {
  PUBLIC_IP=$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo Unknown)
}
