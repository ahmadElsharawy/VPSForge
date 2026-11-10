#!/bin/bash
# Interactive "Add Port Forward Rule": 5 questions (0 = back one step), then conflict check, then add.
_pf_interactive_add() {
  echo
  echo "--- Add Port Forward Rule ---"
  PF_TARGET_VPS=""; PF_INTERNAL_IP=""; PF_EXT_PORT=""; PF_INT_PORT=""; PF_PROTOCOL="tcp"; PF_EXT_IP="0.0.0.0"

  run_wizard _pf_step_target _pf_step_ext_port _pf_step_int_port _pf_step_protocol _pf_step_bind_ip || {
    echo "Cancelled."
    return 1
  }

  local proto conflict conflict_vps
  for proto in $(resolve_protocols "$PF_PROTOCOL"); do
    conflict=$(awk -v p="$proto" -v eip="$PF_EXT_IP" -v eport="$PF_EXT_PORT" -v intip="$PF_INTERNAL_IP" -v intport="$PF_INT_PORT" -F'|' '
      BEGIN { if (eip == "" || eip == "any") eip = "0.0.0.0" }
      {
        r_eip = $2; if (r_eip == "" || r_eip == "any") r_eip = "0.0.0.0";
        if ($1 == p && r_eip == eip && $3 == eport && !($4 == intip && $5 == intport)) {
          print $4 "|" $5; exit
        }
      }
    ' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)

    if [ -n "$conflict" ]; then
      local conf_ip conf_port
      IFS='|' read -r conf_ip conf_port <<< "$conflict"
      conflict_vps=$(get_vps_name_by_ip "$conf_ip" 2>/dev/null || echo "$conf_ip")

      echo "----------------------------------------------------------------"
      echo "PORT CONFLICT DETECTED!"
      echo "External Port $PF_EXT_PORT ($proto) is ALREADY assigned to: $conflict_vps ($conf_ip:$conf_port)"
      echo "----------------------------------------------------------------"
      echo "0) Cancel addition (Default)"
      echo "1) Replace / Overwrite (Move port from $conflict_vps to this VPS)"
      echo "2) Change External Port (Keep internal port $PF_INT_PORT)"

      local choice new_ext_port del_proto
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
            break
            ;;
          2)
            while :; do
              read -r -p "Enter new External Port for this VPS (e.g. 8080, 0=Cancel): " new_ext_port </dev/tty
              [ "${new_ext_port:-0}" = "0" ] && return 1
              if [[ "$new_ext_port" =~ ^[0-9]+$ ]] && [ "$new_ext_port" -ge 1 ] && [ "$new_ext_port" -le 65535 ]; then
                if awk -F'|' -v p="$proto" -v port="$new_ext_port" '$1 == p && $3 == port { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
                  echo "Port $new_ext_port is already used by another rule. Pick a different one."
                  continue
                fi
                PF_EXT_PORT="$new_ext_port"
                break 2
              fi
              echo "Invalid port number."
            done
            ;;
          *) echo "Invalid choice.";;
        esac
      done
    fi
  done

  local host_status=0 go
  port_forward_host_conflict "$PF_EXT_PORT" "$PF_PROTOCOL" || host_status=$?
  if [ "$host_status" -eq 1 ]; then
    return 1
  elif [ "$host_status" -eq 2 ]; then
    read -r -p "Open the port anyway? [y/N]: " go </dev/tty
    [[ "${go,,}" =~ ^y ]] || { echo "Cancelled."; return 1; }
  fi

  echo
  port_forward_cli add "$PF_PROTOCOL" "$PF_EXT_IP" "$PF_EXT_PORT" "$PF_INTERNAL_IP" "$PF_INT_PORT"
}
