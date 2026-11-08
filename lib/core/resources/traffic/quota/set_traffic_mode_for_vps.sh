#!/bin/bash
set_traffic_mode_for_vps() {
  local name="$1" mode="$2" rx_gb="${3:-0}" tx_gb="${4:-0}"
  case "$mode" in
    unlimited)
      incus config set "$name" user.vpsforge.traffic.rx_limit_gb "0" 2>/dev/null || true
      incus config set "$name" user.vpsforge.traffic.tx_limit_gb "0" 2>/dev/null || true
      reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true
      echo "Traffic data limits set to Unlimited for $name and full network speed restored."
      ;;
    limited)
      [[ "$rx_gb" =~ ^[0-9]+$ ]] || rx_gb=0
      [[ "$tx_gb" =~ ^[0-9]+$ ]] || tx_gb=0
      incus config set "$name" user.vpsforge.traffic.rx_limit_gb "$rx_gb" 2>/dev/null || true
      incus config set "$name" user.vpsforge.traffic.tx_limit_gb "$tx_gb" 2>/dev/null || true
      reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true
      check_vps_traffic_quotas >/dev/null 2>&1 || true
      echo "Traffic data limits updated for $name (Download: ${rx_gb}GB, Upload: ${tx_gb}GB)."
      ;;
    *) return 1;;
  esac
}
