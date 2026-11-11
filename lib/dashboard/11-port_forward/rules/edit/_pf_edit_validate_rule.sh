#!/bin/bash
# Validate proposed port-forward rule edits against syntax rules, host conflicts, and existing rules.
_pf_edit_validate_rule() {
  local chk_proto
  for chk_proto in $(resolve_protocols "$(printf '%s' "$new_proto" | tr '[:upper:]' '[:lower:]')"); do
    is_valid_port_forward_rule "$chk_proto" "$new_ext_ip" "$new_ext_port" "$new_int_port" || {
      echo "ERROR: the new rule is not valid (protocol tcp/udp/both, IPv4, ports 1-65535, not 22/80/443). Nothing was changed."
      return 1
    }
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
      echo "ERROR: another rule already uses external port $new_ext_port ($chk_proto). Nothing was changed."
      return 1
    fi
  done
  [[ "$new_int_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: the target has no IP address (is the VPS running?). Nothing was changed."; return 1; }
  return 0
}
