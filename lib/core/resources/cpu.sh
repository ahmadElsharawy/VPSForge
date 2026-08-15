#!/bin/bash
# VPSForge v1.0.0 — CPU resource management.

get_vps_cpu_limit() {
  local configured
  configured=$(incus config get "$1" limits.cpu 2>/dev/null || true)
  if [ -n "$configured" ]; then
    echo "$configured"
  else
    get_host_cpu_count
  fi
}

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

ask_cpu_mode() {
  local c v max
  max=$(get_host_cpu_count)
  while :; do
    echo "----------------------------------------------------------------"
    echo "CPU Mode for $1:"
    echo "0) Back"
    echo "1) Unlimited (all $max core(s) - Default)"
    echo "2) Set CPU Limit"
    read -r -p "Choice [0=Back, Enter=1]: " c
    c="${c:-1}"
    case "$c" in
      0) return 1;;
      1) CPU_MODE_RESULT="unlimited"; CPU_VALUE_RESULT=""; return 0;;
      2)
        while :; do
          read -r -p "CPU Cores (1-$max, or 0 to back): " v
          [ "${v:-}" = "0" ] && continue 2
          if [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -ge 1 ] && [ "$v" -le "$max" ]; then
            CPU_MODE_RESULT="limited"; CPU_VALUE_RESULT="$v"
            return 0
          fi
          echo "ERROR: Server has only $max CPU core(s). Allowed range: 1-$max."
        done
        ;;
      *) echo "Invalid choice.";;
    esac
  done
}
