#!/bin/bash
# Change the internal IP address of a VPS and update its port forwards, DNS, and proxy.
change_vps_ip() {
  local name="$1" new_ip="$2" old_ip port
  [ -n "$name" ] && [ -n "$new_ip" ] || return 1

  local last="${new_ip##*.}" other
  if ! [[ "$new_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ "${new_ip%.*}" != "$NETWORK_PREFIX" ]      || [ "$last" -lt 2 ] || [ "$last" -gt 254 ]; then
    echo "ERROR: The IP must look like ${NETWORK_PREFIX}.150 (last number 2-254)."
    return 1
  fi
  for other in $(incus list -c n --format csv 2>/dev/null); do
    [ "$other" = "$name" ] && continue
    if [ "$(get_ip "$other" 2>/dev/null)" = "$new_ip" ]; then
      echo "ERROR: $new_ip is already used by $other."
      return 1
    fi
  done

  old_ip=$(get_ip "$name")
  port=$(get_port "$old_ip" 2>/dev/null || true)
  [ -n "$port" ] || port=$(get_vps_saved_port "$name")

  _set_vps_ip_safe "$name" "$new_ip" "$old_ip" || return 1
  incus config set "$name" user.vpsforge.ip "$new_ip" 2>/dev/null || true

  if is_vps_running "$name"; then
    apply_guest_static_network "$name" "$new_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || true
    configure_guest_dns "$name" || true
  fi

  [ -n "$old_ip" ] && remove_ip "$old_ip"
  # remove_ip only knows the 9001-9999 range: drop this VPS's own SSH forward by its port too (custom ports).
  [ -n "$port" ] && remove_port "$port"
  [ -n "$old_ip" ] && remap_port_forwards_ip "$old_ip" "$new_ip"
  [ -n "$port" ] && vps_ssh_forward_enabled "$name" && add_forward_rule "$new_ip" "$port"

  update_vps_proxy_ip "$name" "$new_ip"
  sync_vps_metadata "$name"
  echo "Internal IP changed to $new_ip for $name."
}
