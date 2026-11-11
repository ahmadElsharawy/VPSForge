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

  # Check the new values first: nothing is deleted unless the new rule is valid.
  local chk_proto
  for chk_proto in $(resolve_protocols "$(printf '%s' "$new_proto" | tr '[:upper:]' '[:lower:]')"); do
    is_valid_port_forward_rule "$chk_proto" "$new_ext_ip" "$new_ext_port" "$new_int_port" || {
      echo "ERROR: the new rule is not valid (protocol tcp/udp/both, IPv4, ports 1-65535, not 22/80/443). Nothing was changed."; return 1; }
  done
  local edit_host_check go
  for chk_proto in $(resolve_protocols "$(printf '%s' "$new_proto" | tr '[:upper:]' '[:lower:]')"); do
    edit_host_check=0
    port_forward_host_conflict "$new_ext_port" "$chk_proto" >/dev/null 2>&1 || edit_host_check=$?
    [ "$edit_host_check" -eq 1 ] && { echo "ERROR: the host itself uses port $new_ext_port. Nothing was changed."; return 1; }
    if [ "$edit_host_check" -eq 2 ]; then
      port_forward_host_conflict "$new_ext_port" "$chk_proto"
      if [ -z "$go" ]; then
        read -r -p "Open the port anyway? [y/N]: " go </dev/tty
        [[ "${go,,}" =~ ^y ]] || { echo "Cancelled. Nothing was changed."; return 1; }
      fi
    fi
    if awk -F'|' -v p="$chk_proto" -v port="$new_ext_port" -v oe="$old_ext_port" -v oi="$old_int_ip" -v op="$old_int_port" \
        '$1 == p && $3 == port && !($3 == oe && $4 == oi && $5 == op) { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
      echo "ERROR: another rule already uses external port $new_ext_port ($chk_proto). Nothing was changed."; return 1
    fi
  done
  [[ "$new_int_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: the target has no IP address (is the VPS running?). Nothing was changed."; return 1; }

  # Remove old rule & add new rule
  port_forward_cli edit "$old_proto" "${old_ext_ip:-0.0.0.0}" "$old_ext_port" "$old_int_ip" "$old_int_port"     "$new_proto" "$new_ext_ip" "$new_ext_port" "$new_int_ip" "$new_int_port"
}
