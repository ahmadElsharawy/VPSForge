#!/bin/bash

_pf_interactive_edit() {
  echo
  echo "--- Edit Port Forward Rule ---"
  local total
  total=$(count_port_forward_rules)
  [ "$total" -gt 0 ] || { echo "No rules to edit."; return 1; }

  local rule_num old_line
  read -r -p "Select rule # to edit (1-$total, 0=Cancel): " rule_num
  [[ "$rule_num" =~ ^[0-9]+$ ]] && [ "$rule_num" -ge 1 ] && [ "$rule_num" -le "$total" ] || {
    echo "Cancelled."
    return 0
  }

  old_line=$(get_port_forward_rule_by_index "$rule_num")
  [ -n "$old_line" ] || { echo "Rule not found."; return 1; }

  local old_proto old_ext_ip old_ext_port old_int_ip old_int_port
  IFS='|' read -r old_proto old_ext_ip old_ext_port old_int_ip old_int_port <<< "$old_line"

  echo "Editing Rule #$rule_num ($old_proto ${old_ext_ip:-0.0.0.0}:${old_ext_port} -> ${old_int_ip}:${old_int_port}):"

  local new_vps_input target_vps new_int_ip
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

  local new_ext_port
  read -r -p "External Port [Enter = $old_ext_port]: " new_ext_port
  [ -n "$new_ext_port" ] || new_ext_port="$old_ext_port"

  local new_int_port
  read -r -p "Internal Port [Enter = $old_int_port]: " new_int_port
  [ -n "$new_int_port" ] || new_int_port="$old_int_port"

  local new_proto
  read -r -p "Protocol [tcp/udp/both, Enter = $old_proto]: " new_proto
  [ -n "$new_proto" ] || new_proto="$old_proto"

  local new_ext_ip
  read -r -p "External IP [Enter = ${old_ext_ip:-0.0.0.0}]: " new_ext_ip
  [ -n "$new_ext_ip" ] || new_ext_ip="${old_ext_ip:-0.0.0.0}"

  # Remove old rule & add new rule
  port_forward_cli delete "$old_proto" "$old_ext_ip" "$old_ext_port" "$old_int_ip" "$old_int_port"
  port_forward_cli add "$new_proto" "$new_ext_ip" "$new_ext_port" "$new_int_ip" "$new_int_port"
}
