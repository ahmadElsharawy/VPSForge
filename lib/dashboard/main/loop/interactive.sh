#!/bin/bash
# VPSForge v1.0.0 — Main interactive loop.

interactive() {
  # Enter alternate screen buffer & trap exit/interrupt to restore terminal state
  printf "\033[?1049h"
  trap 'printf "\033[?1049l"' EXIT INT TERM

  local c
  local is_refresh=0
  local INPUT_BUFFER=""
  local char
  load_settings

  while :; do
    if [ "$is_refresh" -eq 1 ]; then
      dashboard refresh
    elif [ -z "$INPUT_BUFFER" ]; then
      dashboard full
    fi
    is_refresh=0

    char=""
    if [ "$AUTO_REFRESH" = "on" ] && [ -z "$INPUT_BUFFER" ]; then
      if ! read -s -n 1 -t "$REFRESH_INTERVAL" char; then
        get_network_info
        get_public_ip
        is_refresh=1
        continue
      fi
    else
      read -s -n 1 char
    fi

    # Handle Enter (newline)
    if [ -z "$char" ]; then
      if [ -z "$INPUT_BUFFER" ]; then
        # Enter on empty line triggers refresh
        get_network_info
        get_public_ip
        is_refresh=1
        continue
      else
        c="$INPUT_BUFFER"
        INPUT_BUFFER=""
        echo
      fi
    # Handle Backspace
    elif [[ "$char" == $'\x7f' || "$char" == $'\x08' ]]; then
      if [ -n "$INPUT_BUFFER" ]; then
        INPUT_BUFFER="${INPUT_BUFFER%?}"
        printf "\b \b"
      fi
      continue
    # Handle digits
    elif [[ "$char" =~ ^[0-9]$ ]]; then
      INPUT_BUFFER="${INPUT_BUFFER}${char}"
      printf "%s" "$char"
      continue
    else
      # Ignore other keys
      continue
    fi

    case "$c" in
      0)
        get_network_info
        get_public_ip
        is_refresh=1
        continue
        ;;
      1)  add_menu;;
      2)  delete_vps_menu;;
      3)  start_vps_menu;;
      4)  stop_vps_menu;;
      5)  restart_vps_menu;;
      6)  reinstall_vps_menu;;
      7)  edit_vps_menu;;
      8)  bulk_details_menu; pause;;
      9)  shell_menu;;
      10) bulk_connection_menu; pause;;
      11) port_forward_menu;;
      12) proxy_menu;;
      13) backup_vps_menu;;
      14) settings_menu;;
      15)
        printf "\033[?1049l"
        echo "Goodbye!"
        return 0 2>/dev/null || exit 0
        ;;
      *)  is_refresh=1; continue;;
    esac
  done
}
