#!/bin/bash
# Sets CPU limit (unlimited or 1..max cores) for a VPS container.
set_cpu_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual
  max=$(get_host_cpu_count)
  case "$mode" in
    unlimited)
      incus config unset "$name" limits.cpu 2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ] || {
        echo "ERROR: CPU limit must be between 1 and $max."
        return 1
      }
      incus config set "$name" limits.cpu "$value" || return 1
      actual=$(incus config get "$name" limits.cpu 2>/dev/null || true)
      [ "$actual" = "$value" ] || {
        echo "ERROR: CPU verification failed for $name."
        return 1
      }
      ;;
    *) return 1;;
  esac
}
