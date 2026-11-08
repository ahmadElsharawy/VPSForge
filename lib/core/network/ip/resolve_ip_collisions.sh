#!/bin/bash
resolve_ip_collisions() {
  local -a all_vps
  mapfile -t all_vps < <(incus list -c n --format csv 2>/dev/null | grep -v '^$' | sort -V || true)
  local seen_ips=() v ip static_ip static_gateway static_netmask

  for v in "${all_vps[@]}"; do
    ip=$(get_ip "$v" 2>/dev/null || true)
    [ -z "$ip" ] || [ "$ip" = "-" ] && continue

    if [[ " ${seen_ips[*]} " == *" $ip "* ]]; then
      echo "WARNING: IP Conflict detected for '$v' on IP $ip. Preserving original identity/port."
      static_ip=$(incus config get "$v" user.vpsforge.ip 2>/dev/null || true)
      if [ -n "$static_ip" ] && is_vps_running "$v"; then
        apply_guest_static_network "$v" "$static_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" >/dev/null 2>&1 || true
      fi
    else
      seen_ips+=("$ip")
    fi
  done
}
