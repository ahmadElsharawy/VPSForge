#!/bin/bash
# Sets root disk limit (unlimited or min_disk..max GB) for a VPS container.
set_disk_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max min_disk=3 actual
  repair_pool_quotas   # the limit only works while btrfs quota data is consistent
  max=$(get_disk_available_for_vps "$name")
  ensure_device_override "$name" root || return 1

  case "$mode" in
    unlimited)
      incus config device unset "$name" root size 2>/dev/null || true
      ;;
    limited)
      [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$min_disk" ] && [ "$value" -le "$max" ] || {
        echo "ERROR: Disk limit must be between ${min_disk}GB and ${max}GB (available)."
        return 1
      }
      incus config device set "$name" root size "${value}GiB" || return 1
      actual=$(incus config device get "$name" root size 2>/dev/null || true)
      [ "$actual" = "${value}GiB" ] || {
        echo "ERROR: Disk verification failed for $name. Requested=${value}GiB Actual=${actual:-none}"
        return 1
      }
      ;;
    *) return 1;;
  esac
}
