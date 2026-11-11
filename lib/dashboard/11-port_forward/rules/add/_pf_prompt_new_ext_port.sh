#!/bin/bash
# Prompt the user for an alternative external port that is not already in use.
#   _pf_prompt_new_ext_port <proto>
_pf_prompt_new_ext_port() {
  local proto="$1" new_ext_port
  while :; do
    read -r -p "Enter new External Port for this VPS (e.g. 8080, 0=Cancel): " new_ext_port </dev/tty
    [ "${new_ext_port:-0}" = "0" ] && return 1
    if [[ "$new_ext_port" =~ ^[0-9]+$ ]] && [ "$new_ext_port" -ge 1 ] && [ "$new_ext_port" -le 65535 ]; then
      if awk -F'|' -v p="$proto" -v port="$new_ext_port" '$1 == p && $3 == port { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
        echo "Port $new_ext_port is already used by another rule. Pick a different one."
        continue
      fi
      PF_EXT_PORT="$new_ext_port"
      return 0
    fi
    echo "Invalid port number."
  done
}
