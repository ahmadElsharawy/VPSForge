#!/bin/bash
# Give a VPS's network card a fixed address and check that Incus really took it.
# Returns 1 (with the reason) when Incus refuses, e.g. the address is still used by another VPS.
#   set_vps_device_ip <vps> <ip>
set_vps_device_ip() {
  local name="${1:?vps}" ip="${2:?ip}" out
  ensure_device_override "$name" eth0 || return 1
  if ! out=$(incus config device set "$name" eth0 ipv4.address "$ip" 2>&1); then
    echo "ERROR: Incus refused address $ip for $name: $out"
    return 1
  fi
  [ "$(incus config device get "$name" eth0 ipv4.address 2>/dev/null)" = "$ip" ]
}
