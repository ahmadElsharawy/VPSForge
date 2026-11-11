#!/bin/bash
# Prompt the user for action when an external port conflict is detected (cancel, replace, change port).
#   _pf_prompt_conflict_action <proto> <conflict_ip|conflict_port>
_pf_prompt_conflict_action() {
  local proto="$1" conflict="$2"
  local conf_ip conf_port conflict_vps
  IFS='|' read -r conf_ip conf_port <<< "$conflict"
  conflict_vps=$(get_vps_name_by_ip "$conf_ip" 2>/dev/null || echo "$conf_ip")

  echo "----------------------------------------------------------------"
  echo "PORT CONFLICT DETECTED!"
  echo "External Port $PF_EXT_PORT ($proto) is ALREADY assigned to: $conflict_vps ($conf_ip:$conf_port)"
  echo "----------------------------------------------------------------"
  echo "0) Cancel addition (Default)"
  echo "1) Replace / Overwrite (Move port from $conflict_vps to this VPS)"
  echo "2) Change External Port (Keep internal port $PF_INT_PORT)"

  local choice del_proto
  while :; do
    read -r -p "Choice [0=Cancel, 1=Replace, 2=Change Port, Enter=0]: " choice </dev/tty
    choice="${choice:-0}"
    case "$choice" in
      0)
        echo "Operation cancelled."
        return 1
        ;;
      1)
        echo "Replacing port mapping: removing from $conflict_vps..."
        for del_proto in $(resolve_protocols "$PF_PROTOCOL"); do
          port_forward_cli delete "$del_proto" "$PF_EXT_IP" "$PF_EXT_PORT" "$conf_ip" "$conf_port" >/dev/null 2>&1
        done
        return 0
        ;;
      2)
        _pf_prompt_new_ext_port "$proto" || return 1
        return 0
        ;;
      *) echo "Invalid choice.";;
    esac
  done
}
