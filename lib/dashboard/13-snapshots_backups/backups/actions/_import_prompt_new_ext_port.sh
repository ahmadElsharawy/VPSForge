#!/bin/bash
# Prompt user for a replacement external port during backup import conflict resolution.
_import_prompt_new_ext_port() {
  local proto="$1" ext_ip="$2" int_port="$3" old_ip="$4"
  local new_ext_port host_check port_declined go

  while :; do
    read -r -p "   Enter new external port for $proto [0=Cancel]: " new_ext_port </dev/tty
    [ "${new_ext_port:-0}" = "0" ] && return 1
    if [[ "$new_ext_port" =~ ^[0-9]+$ ]] && [ "$new_ext_port" -gt 0 ] && [ "$new_ext_port" -lt 65536 ]; then
      host_check=0
      port_forward_host_conflict "$new_ext_port" "$proto" >/dev/null 2>&1 || host_check=$?
      port_declined=0
      if [ "$host_check" -eq 2 ] && is_valid_port_forward_rule "$proto" "$ext_ip" "$new_ext_port" "$int_port"; then
        port_forward_host_conflict "$new_ext_port" "$proto" | sed 's/^/   /'
        read -r -p "   Use it anyway? [y/N]: " go </dev/tty
        [[ "${go,,}" =~ ^y ]] || port_declined=1
      fi
      if ! is_valid_port_forward_rule "$proto" "$ext_ip" "$new_ext_port" "$int_port"; then
        echo "   ERROR: that port is not allowed (22, 80 and 443 are reserved)."
      elif [ "$host_check" -eq 1 ]; then
        echo "   ERROR: the host itself uses port $new_ext_port. Try another one."
      elif [ "$port_declined" -eq 1 ]; then
        echo "   Port $new_ext_port was not accepted. Try another one."
      elif ! awk -F'|' -v p="$proto" -v port="$new_ext_port" -v oldip="$old_ip" 'BEGIN { f=0 } $1 == p && $3 == port && $4 != oldip { f=1; exit } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
        ext_port="$new_ext_port"
        return 0
      else
        echo "   ERROR: Port $new_ext_port is also occupied. Try another one."
      fi
    else
      echo "   ERROR: Invalid port number. Must be 1-65535."
    fi
  done
}
