#!/bin/bash
# Configure and activate static IPv4 networking across supported guest Linux distros.
apply_guest_static_network() {
  local name="$1" ip="$2" gateway="$3" prefix="${4:-24}"
  local mask
  mask="$(_cidr_to_netmask "$prefix")"

  _apply_guest_netplan "$name" "$ip" "$gateway" "$prefix"
  _apply_guest_systemd_networkd "$name" "$ip" "$gateway" "$prefix"
  _apply_guest_ifupdown "$name" "$ip" "$gateway" "$mask"
  _apply_guest_networkmanager "$name" "$ip" "$gateway" "$prefix"
  _apply_guest_sysconfig "$name" "$ip" "$gateway" "$prefix"

  _apply_guest_runtime_ip "$name" "$ip" "$gateway" "$prefix"
}
