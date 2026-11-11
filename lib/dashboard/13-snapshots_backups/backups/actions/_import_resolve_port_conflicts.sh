#!/bin/bash
# Scan port forwarding rules from backup archive and resolve any port conflicts.
_import_resolve_port_conflicts() {
  [ -n "$rules" ] || return 0

  echo
  echo "Scanning Port Forwarding rules for conflicts..."
  local rules_arr rule proto ext_ip ext_port int_port other_vps action
  IFS=';' read -ra rules_arr <<< "$rules"
  for rule in "${rules_arr[@]}"; do
    [ -n "$rule" ] || continue
    IFS='|' read -r proto ext_ip ext_port int_port <<< "$rule"
    [ -n "$proto" ] && [ -n "$ext_port" ] || continue
    is_valid_port_forward_rule "$proto" "$ext_ip" "$ext_port" "$int_port" || { echo "Skipped unsafe or invalid forward rule: $rule"; continue; }
    # The SSH forward (port -> 22) is not restored: the import gives the new VPS its own SSH port,
    # so asking about a conflict with the old VPS's SSH port would be pointless.
    [ "$int_port" = "22" ] && continue
    port_forward_host_conflict "$ext_port" "$proto" >/dev/null 2>&1
    [ "$?" -ne 0 ] && { echo "Skipped forward $proto:$ext_port (the host uses that port)."; continue; }

    other_vps=$(awk -F'|' -v p="$proto" -v port="$ext_port" -v oldip="$old_ip" '$1 == p && $3 == port && $4 != oldip { print $4; exit }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null || true)
    if [ -n "$other_vps" ]; then
      echo
      echo "⚠️  PORT FORWARD CONFLICT detected for Rule [ $proto:$ext_port -> $int_port ]"
      echo "   External port $ext_port ($proto) is already used by VPS IP $other_vps."
      echo "   1) Change external port"
      echo "   2) Skip this rule (Default)"
      read -r -p "   Choice [1-2, Enter=2]: " action </dev/tty
      action="${action:-2}"
      if [ "$action" = "1" ]; then
        _import_prompt_new_ext_port "$proto" "$ext_ip" "$int_port" "$old_ip"
        rules_to_apply+=("${proto}|${ext_ip}|${ext_port}|${int_port}")
      else
        echo "   Skipped rule [ $proto:$ext_port -> $int_port ]."
      fi
    else
      rules_to_apply+=("${proto}|${ext_ip}|${ext_port}|${int_port}")
    fi
  done
}
