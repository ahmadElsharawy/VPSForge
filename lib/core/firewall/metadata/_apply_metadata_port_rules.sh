#!/bin/bash
# Apply port forward rules defined in a container's metadata rules string.
_apply_metadata_port_rules() {
  local ip="$1" rules="$2"
  local rule proto ext_ip ext_port int_port
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
    if awk -F'|' -v p="$proto" -v port="$ext_port" -v ip="$ip" '$1 == p && $3 == port && $4 != ip { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
      echo "Skipped forward $proto:$ext_port (another VPS holds it now)."; continue
    fi

    # Apply custom rule with the container's current IP
    port_forward_apply_rule "$proto" "$ext_ip" "$ext_port" "$ip" "$int_port"
    port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" "$proto" "$ext_ip" "$ext_port" "$ip" "$int_port"
  done
}
