#!/bin/bash
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

  incus config set "$name" user.vpsforge.ip "$new_ip" 2>/dev/null || true
  configure_vps_network_device "$name" "$new_ip" || true

  if is_vps_running "$name"; then
    apply_guest_static_network "$name" "$new_ip" "$INCUS_GATEWAY" "${INCUS_NETMASK:-24}" || true
    configure_guest_dns "$name" || true
  fi

  [ -n "$old_ip" ] && remove_ip "$old_ip"
  [ -n "$port" ] && add_forward_rule "$new_ip" "$port"

  update_vps_proxy_ip "$name" "$new_ip"
  sync_vps_metadata "$name"
  echo "Internal IP changed to $new_ip for $name."
}
