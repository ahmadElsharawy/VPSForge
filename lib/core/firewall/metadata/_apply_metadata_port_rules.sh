#!/bin/bash
# Apply port forward rules defined in a container's metadata rules string.
_apply_metadata_port_rules() {
  local ip="$1" rules="$2"
  local rule proto ext_ip ext_port int_port conflict_ip conflict_owner this_vps tmpf
  local -a rule_arr=()

  mkdir -p "$(dirname "$PORT_FORWARD_RULES_FILE")"
  touch "$PORT_FORWARD_RULES_FILE"
  IFS=';' read -ra rule_arr <<< "$rules"
  for rule in "${rule_arr[@]}"; do
    [ -n "$rule" ] || continue
    IFS='|' read -r proto ext_ip ext_port int_port <<< "$rule"
    # Skip empty values
    [ -n "$proto" ] && [ -n "$ext_port" ] || continue
    is_valid_port_forward_rule "$proto" "$ext_ip" "$ext_port" "$int_port" || continue

    # Never take a port the host itself uses, or one another VPS holds now
    port_forward_host_conflict "$ext_port" "$proto" >/dev/null 2>&1
    [ "$?" -ne 0 ] && { echo "Skipped forward $proto:$ext_port (the host uses that port)."; continue; }
    conflict_ip=$(awk -F'|' -v p="$proto" -v port="$ext_port" -v ip="$ip" '$1 == p && $3 == port && $4 != ip { print $4; exit }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)
    if [ -n "$conflict_ip" ]; then
      conflict_owner=$(get_vps_name_by_ip "$conflict_ip" 2>/dev/null || true)
      this_vps=$(get_vps_name_by_ip "$ip" 2>/dev/null || true)
      if [ -n "$conflict_owner" ] && [ "$conflict_owner" != "$this_vps" ]; then
        echo "Skipped forward $proto:$ext_port (another VPS holds it now)."; continue
      fi
      tmpf=$(mktemp)
      awk -F'|' -v p="$proto" -v port="$ext_port" -v old="$conflict_ip" '!($1 == p && $3 == port && $4 == old)' "$PORT_FORWARD_RULES_FILE" > "$tmpf" 2>/dev/null && mv -f "$tmpf" "$PORT_FORWARD_RULES_FILE"
      port_forward_delete_rule "$proto" "" "$ext_port" "$conflict_ip" "" 2>/dev/null || true
    fi

    # Apply custom rule with the container's current IP
    port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$ip" "$int_port"
    port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" "$proto" "$ext_ip" "$ext_port" "$ip" "$int_port"
  done
}
