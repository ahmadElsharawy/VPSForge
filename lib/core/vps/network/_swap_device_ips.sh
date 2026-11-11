#!/bin/bash
# Stepwise swap of container device IPs using a spare address, rolling back on error.
_swap_device_ips() {
  local name_a="$1" name_b="$2" ip_a="$3" ip_b="$4" spare="$5"
  set_vps_device_ip "$name_a" "$spare" || { echo "Nothing was changed."; return 1; }
  if ! set_vps_device_ip "$name_b" "$ip_a"; then
    set_vps_device_ip "$name_a" "$ip_a" >/dev/null 2>&1 || true
    echo "Nothing was changed."; return 1
  fi
  if ! set_vps_device_ip "$name_a" "$ip_b"; then
    set_vps_device_ip "$name_b" "$ip_b" >/dev/null 2>&1 || true
    set_vps_device_ip "$name_a" "$ip_a" >/dev/null 2>&1 || true
    echo "Nothing was changed."; return 1
  fi
}
