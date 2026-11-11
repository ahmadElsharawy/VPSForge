#!/bin/bash
# Remove saved port-forward firewall rules recorded in PORT_FORWARD_RULES_FILE.
_uninstall_remove_saved_forwards() {
  local proto ext_ip ext_port int_ip int_port
  [ -f "$PORT_FORWARD_RULES_FILE" ] || return 0
  while IFS='|' read -r proto ext_ip ext_port int_ip int_port; do
    [ -n "$proto" ] && [ -n "$ext_port" ] || continue
    if [ "${UNINSTALL_DRY_RUN:-0}" = "1" ]; then
      echo "  - remove forward $proto $ext_port -> $int_ip:$int_port"
    else
      port_forward_delete_rule "$proto" "$ext_ip" "$ext_port" "$int_ip" "$int_port"
    fi
  done < "$PORT_FORWARD_RULES_FILE"
}
