#!/bin/bash

_pf_interactive_add() {
  echo
  echo "--- Add Port Forward Rule ---"

  local target_vps="" internal_ip="" vps_input
  list_available_vps || true
  read -r -p "Select target VPS by number, name, or enter custom IP address: " vps_input </dev/tty
  [ -n "$vps_input" ] || { echo "Cancelled."; return 1; }

  if [[ "$vps_input" =~ ^[0-9]+$ ]] && [ "$vps_input" -ge 1 ] && [ "$vps_input" -le "${#AVAILABLE_VPS_LIST[@]}" ]; then
    local idx=$((vps_input - 1))
    target_vps="${AVAILABLE_VPS_LIST[$idx]}"
  elif [[ "$vps_input" =~ ^[0-9]+$ ]]; then
    target_vps="${VPS_PREFIX}${vps_input}"
  else
    target_vps="$vps_input"
  fi

  if incus info "$target_vps" >/dev/null 2>&1; then
    internal_ip=$(get_ip "$target_vps")
    if [ -z "$internal_ip" ]; then
      echo "ERROR: $target_vps is currently stopped or has no IP allocated."
      return 1
    fi
    echo "Selected VPS: $target_vps (Internal IP: $internal_ip)"
  elif [[ "$vps_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    internal_ip="$vps_input"
    echo "Using custom IP: $internal_ip"
  else
    echo "ERROR: Invalid VPS or IP address: $vps_input"
    return 1
  fi

  local external_port
  while :; do
    read -r -p "External Port (e.g. 8080): " external_port
    [[ "$external_port" =~ ^[0-9]+$ ]] && [ "$external_port" -ge 1 ] && [ "$external_port" -le 65535 ] && break
    echo "Invalid port. Must be between 1 and 65535."
  done

  local internal_port
  read -r -p "Internal Port [Enter = $external_port]: " internal_port
  [ -n "$internal_port" ] || internal_port="$external_port"
  [[ "$internal_port" =~ ^[0-9]+$ ]] && [ "$internal_port" -ge 1 ] && [ "$internal_port" -le 65535 ] || {
    echo "Invalid internal port."
    return 1
  }

  local proto_choice protocol="tcp"
  echo "Protocol:"
  echo "  1) TCP (default)"
  echo "  2) UDP"
  echo "  3) BOTH (TCP + UDP)"
  read -r -p "Choice [1-3, Enter=1]: " proto_choice
  case "$proto_choice" in
    2) protocol="udp";;
    3) protocol="both";;
    *) protocol="tcp";;
  esac

  local external_ip
  read -r -p "External Bind IP [Enter = 0.0.0.0 (All Interfaces)]: " external_ip
  [ -n "$external_ip" ] || external_ip="0.0.0.0"

  local proto conflict conflict_vps
  for proto in $(resolve_protocols "$protocol"); do
    conflict=$(awk -v p="$proto" -v eip="$external_ip" -v eport="$external_port" -v intip="$internal_ip" -F'|' '
      BEGIN { if (eip == "") eip = "0.0.0.0" }
      {
        r_eip = $2; if (r_eip == "") r_eip = "0.0.0.0";
        if ($1 == p && r_eip == eip && $3 == eport && $4 != intip) {
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
      echo "External Port $external_port ($proto) is ALREADY assigned to: $conflict_vps ($conf_ip:$conf_port)"
      echo "----------------------------------------------------------------"
      echo "0) Cancel addition (Default)"
      echo "1) Replace / Overwrite (Move port from $conflict_vps to this VPS)"
      echo "2) Change External Port (Keep internal port $internal_port)"
      
      local choice new_ext_port
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
            port_forward_cli delete "$proto" "$external_ip" "$external_port" "$conf_ip" "$conf_port" >/dev/null 2>&1
            break
            ;;
          2)
            while :; do
              read -r -p "Enter new External Port for this VPS (e.g. 8080, 0=Cancel): " new_ext_port </dev/tty
              [ "${new_ext_port:-0}" = "0" ] && return 1
              if [[ "$new_ext_port" =~ ^[0-9]+$ ]] && [ "$new_ext_port" -ge 1 ] && [ "$new_ext_port" -le 65535 ]; then
                external_port="$new_ext_port"
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

  echo
  port_forward_cli add "$protocol" "$external_ip" "$external_port" "$internal_ip" "$internal_port"
}
