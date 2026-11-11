#!/bin/bash
# Prompt the user for new port-forward rule values (target VPS, ports, protocol, external IP).
_pf_edit_prompt_values() {
  local new_vps_input target_vps
  list_available_vps || true
  read -r -p "Target VPS / IP [Enter = $old_int_ip]: " new_vps_input </dev/tty
  if [ -z "$new_vps_input" ]; then
    new_int_ip="$old_int_ip"
  else
    if [[ "$new_vps_input" =~ ^[0-9]+$ ]] && [ "$new_vps_input" -ge 1 ] && [ "$new_vps_input" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
      local idx=$((new_vps_input - 1))
      target_vps="${AVAILABLE_VPS_LIST[$idx]}"
    elif [[ "$new_vps_input" =~ ^[0-9]+$ ]]; then
      target_vps="${VPS_PREFIX}${new_vps_input}"
    else
      target_vps="$new_vps_input"
    fi
    if incus info "$target_vps" >/dev/null 2>&1; then
      new_int_ip=$(get_ip "$target_vps")
    else
      new_int_ip="$new_vps_input"
    fi
  fi

  read -r -p "External Port [Enter = $old_ext_port]: " new_ext_port
  [ -n "$new_ext_port" ] || new_ext_port="$old_ext_port"

  read -r -p "Internal Port [Enter = $old_int_port]: " new_int_port
  [ -n "$new_int_port" ] || new_int_port="$old_int_port"

  read -r -p "Protocol [tcp/udp/both, Enter = $old_proto]: " new_proto
  [ -n "$new_proto" ] || new_proto="$old_proto"

  read -r -p "External IP [Enter = ${old_ext_ip:-0.0.0.0}]: " new_ext_ip
  [ -n "$new_ext_ip" ] || new_ext_ip="${old_ext_ip:-0.0.0.0}"
  return 0
}
