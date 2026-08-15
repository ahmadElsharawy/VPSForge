#!/bin/bash
# VPSForge v1.0.0 — Network speed limit management.

get_vps_network_limit_mbit() {
  local raw
  raw=$(incus config device get "$1" eth0 limits.ingress 2>/dev/null || true)
  [[ "$raw" =~ ^([0-9]+)[Mm]bit$ ]] && echo "${BASH_REMATCH[1]}" || true
}

set_network_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual_in actual_out
  max=100000
  ensure_device_override "$name" eth0 || return 1

  case "$mode" in
    unlimited)
      incus config device unset "$name" eth0 limits.ingress 2>/dev/null || true
      incus config device unset "$name" eth0 limits.egress  2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ] || {
        echo "ERROR: Network limit must be between 1 and $max Mbit."
        return 1
      }
      incus config device set "$name" eth0 limits.ingress "${value}Mbit" || return 1
      incus config device set "$name" eth0 limits.egress  "${value}Mbit" || return 1

      actual_in=$(incus config device get "$name" eth0 limits.ingress 2>/dev/null || true)
      actual_out=$(incus config device get "$name" eth0 limits.egress 2>/dev/null || true)
      [ "$actual_in" = "${value}Mbit" ] && [ "$actual_out" = "${value}Mbit" ] || {
        echo "ERROR: Network verification failed for $name."
        return 1
      }
      ;;
    *) return 1;;
  esac
}

ask_network_mode() {
  local c v max
  max=$(get_total_network_mbit)
  while :; do
    echo "----------------------------------------------------------------"
    echo "Network Mode for $1:"
    echo "Total Network Speed: ${max} Mbit"
    echo "0) Back"
    echo "1) Unlimited (Full Host Speed - Default)"
    echo "2) Set Speed Limit"
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"
    case "$c" in
      0) return 1;;
      1) NETWORK_MODE_RESULT="unlimited"; NETWORK_VALUE_RESULT=""; return 0;;
      2)
        while :; do
          read -r -p "Network Limit in Mbit (1-100000, e.g. 2500, or 0 to back): " v
          [ "${v:-}" = "0" ] && continue 2
          if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le 100000 ]; then
            NETWORK_MODE_RESULT="limited"; NETWORK_VALUE_RESULT="$v"
            return 0
          fi
          echo "Invalid network limit."
        done
        ;;
      *) echo "Invalid choice.";;
    esac
  done
}

format_network_display() {
  local name="$1" limit io
  limit=$(get_vps_network_limit_mbit "$name" 2>/dev/null || true)
  io=$(get_vps_network_io_display "$name" 2>/dev/null || echo "-")
  if [ -n "$limit" ]; then
    echo "${limit}M [${io}]"
  else
    local max
    max=$(get_total_network_mbit 2>/dev/null || echo 10000)
    echo "${max}M [${io}]"
  fi
}
