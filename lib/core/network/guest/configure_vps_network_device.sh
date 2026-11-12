#!/bin/bash
# Point a VPS's eth0 at the VPSForge bridge, optionally with a fixed address.
#   configure_vps_network_device <vps> [ip]
configure_vps_network_device() {
  local name="$1" ip="${2:-}"
  ensure_device_override "$name" eth0 || return 1
  if [ -n "$ip" ]; then
    incus config device set "$name" eth0 ipv4.address "$ip" >/dev/null 2>&1 || true
  else
    incus config device unset "$name" eth0 ipv4.address >/dev/null 2>&1 || true
  fi
  incus config device unset "$name" eth0 ipv4.gateway >/dev/null 2>&1 || true
  # The volatile keys tie the card to its live host side: removing them on a RUNNING VPS makes
  # Incus refuse every later change of this card until a restart, so only do it when stopped.
  if ! is_vps_running "$name"; then
    incus config device unset "$name" eth0 hwaddr >/dev/null 2>&1 || true
    incus config unset "$name" volatile.eth0.hwaddr >/dev/null 2>&1 || true
    incus config unset "$name" volatile.eth0.host_name >/dev/null 2>&1 || true
  fi
  incus config device set "$name" eth0 name eth0 || true
  incus config device set "$name" eth0 network incusbr0 || true
}
