#!/bin/bash
# VPSForge — Core constants and shared helpers.

# ── Constants ────────────────────────────────────────────────────────────────

VPS_PREFIX="vps"
VPS_IMAGE="images:ubuntu/24.04"
SSH_PORT_BASE=9000
IP_START=11
ROOT_PASSWORD="root"
MIN_RAM_MB=128
PORT_FORWARD_RULES_FILE="/opt/vpsforge/port-forwards.conf"
BACKUP_DIR="/opt/vpsforge-backups"
UBUNTU_IMAGES_CACHE_FILE="/opt/vpsforge/ubuntu_images_cache.txt"

# ── Helpers ──────────────────────────────────────────────────────────────────

pause() { read -r -p "Press Enter to continue..."; }

# Extract or lookup numeric identifier for a VPS (e.g. vps3 → 3, or custom name → metadata/IP num)
get_num() {
  local name="$1" num ip last_octet
  num=$(incus config get "$name" user.vpsforge.num 2>/dev/null || true)
  if [[ "$num" =~ ^[0-9]+$ ]]; then
    echo "$num"
    return
  fi
  if [[ "$name" =~ ^${VPS_PREFIX}([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  ip=$(incus config get "$name" user.vpsforge.ip 2>/dev/null || true)
  if [[ "$ip" =~ \.([0-9]+)$ ]]; then
    last_octet="${BASH_REMATCH[1]}"
    echo $((last_octet - IP_START + 1))
    return
  fi
  echo "$name" | sed "s/^${VPS_PREFIX}//"
}

# Convert a human-readable RAM string to plain megabytes.
ram_mb() {
  case "$1" in
    *MiB)      echo "${1%MiB}";;
    *GiB)      echo $(( ${1%GiB} * 1024 ));;
    *MB)       echo "${1%MB}";;
    *GB)       echo $(( ${1%GB} * 1000 ));;
    Unlimited|"") echo 0;;
    *)         echo "$1";;
  esac
}

# ── Firewall Persistence ────────────────────────────────────────────────────

# Persist current iptables rules to disk.
# Tries netfilter-persistent first, falls back to iptables-save.
save_iptables() {
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
  else
    mkdir -p /etc/iptables 2>/dev/null || true
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
  fi
}
