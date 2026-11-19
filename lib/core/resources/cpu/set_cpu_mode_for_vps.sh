#!/bin/bash
# Sets CPU limit (unlimited or 1..max cores) and usage cap for a VPS container.
set_cpu_mode_for_vps() {
  local name="$1" mode="$2" value="${3:-}" max actual
  max=$(get_host_cpu_count)
  split_cpu_value "$value"
  case "$mode" in
    unlimited)
      incus config unset "$name" limits.cpu 2>/dev/null || true
      ;;
    limited)
      [[ "$CPU_CORES_PART" =~ ^[0-9]+$ ]] && [ "$CPU_CORES_PART" -ge 1 ] && [ "$CPU_CORES_PART" -le "$max" ] || {
        echo "ERROR: CPU limit must be between 1 and $max."
        return 1
      }
      incus config set "$name" limits.cpu "$CPU_CORES_PART" || return 1
      actual=$(incus config get "$name" limits.cpu 2>/dev/null || true)
      [ "$actual" = "$CPU_CORES_PART" ] || {
        echo "ERROR: CPU verification failed for $name."
        return 1
      }
      ;;
    *) return 1;;
  esac
  if [ -n "$CPU_ALLOWANCE_PART" ]; then
    is_valid_cpu_allowance "$CPU_ALLOWANCE_PART" || {
      echo "ERROR: CPU allowance must be between 1 and 100."
      return 1
    }
    cpu_cap_to_allowance "$CPU_ALLOWANCE_PART" "${CPU_CORES_PART:-$max}"
    if [ -z "$CPU_ALLOWANCE_VALUE" ]; then
      incus config unset "$name" limits.cpu.allowance 2>/dev/null || true
      incus config unset "$name" user.vpsforge.cpu_cap 2>/dev/null || true
    else
      incus config set "$name" limits.cpu.allowance "$CPU_ALLOWANCE_VALUE" || return 1
      incus config set "$name" user.vpsforge.cpu_cap "$CPU_ALLOWANCE_PART" || return 1
    fi
    actual=$(incus config get "$name" limits.cpu.allowance 2>/dev/null || true)
    [ "$actual" = "$CPU_ALLOWANCE_VALUE" ] || {
      echo "ERROR: CPU allowance verification failed for $name."
      return 1
    }
  fi
}
