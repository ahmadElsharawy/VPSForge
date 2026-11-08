#!/bin/bash
set_ram_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" actual
  case "$mode" in
    unlimited)
      incus config unset "$name" limits.memory 2>/dev/null || true
      actual=$(incus config get "$name" limits.memory 2>/dev/null || true)
      [ -z "$actual" ] || {
        echo "ERROR: Failed to remove RAM limit from $name."
        return 1
      }
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$MIN_RAM_MB" ] || {
        echo "ERROR: Invalid RAM limit: $value MB."
        return 1
      }
      incus config set "$name" limits.memory "${value}MiB" || return 1
      actual=$(incus config get "$name" limits.memory 2>/dev/null || true)
      [ "$(ram_mb "$actual")" = "$value" ] || {
        echo "ERROR: RAM verification failed for $name. Requested=${value}MB Actual=${actual:-none}"
        return 1
      }
      ;;
    *) return 1;;
  esac
}
