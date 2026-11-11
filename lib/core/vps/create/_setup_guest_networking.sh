#!/bin/bash
# Apply static IP and DNS inside the guest container, retrying if necessary.
#   _setup_guest_networking <name> <ip> <port>
_setup_guest_networking() {
  local name="$1" ip="$2" port="$3"

  echo "Applying guest network config in $name..."
  apply_guest_static_network "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || {
    echo "ERROR: Failed to apply guest network config for $name."
    diagnose_guest_network "$name" "$ip"
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }

  configure_guest_dns "$name" || {
    echo "ERROR: Failed to configure guest DNS for $name."
    diagnose_guest_network "$name" "$ip"
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  }

  # Some systems (Alpine's dhcpcd) rewrite DNS a moment after boot: re-apply it a few times before giving up.
  local net_try=0
  until guest_network_config_ok "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || [ "$net_try" -ge 4 ]; do
    net_try=$((net_try + 1))
    sleep 3
    configure_guest_dns "$name" >/dev/null 2>&1 || true
  done
  if ! guest_network_config_ok "$name" "$ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}"; then
    echo "ERROR: Guest network still looks incomplete after guest network setup."
    diagnose_guest_network "$name" "$ip"
    _rollback_vps_full "$name" "$ip" "$port"
    return 1
  fi
}
