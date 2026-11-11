#!/bin/bash
# Sets network ingress/egress speed limit (unlimited or 1..100000 Mbit) for a VPS container.
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
