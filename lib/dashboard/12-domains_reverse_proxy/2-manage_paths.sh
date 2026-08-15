#!/bin/bash
# VPSForge v1.0.0 — Manage VPS proxy paths.

manage_vps_proxy() {
  ensure_caddy_installed
  select_vps || return
  local vps_name="$SELECTED"

  local ip
  ip=$(get_ip "$vps_name")
  if [ -z "$ip" ] || [ "$ip" = "-" ]; then
    echo "ERROR: VPS '$vps_name' has no IPv4 address. Make sure it is running."
    sleep 2
    return
  fi

  local conf_file="$CADDY_CONF_DIR/${vps_name}.caddy"

  while true; do
    clear
    local domain="NOT LINKED YET"
    if [ -f "$conf_file" ]; then
      domain=$(head -n 1 "$conf_file" | awk '{print $1}')
    fi

    echo "================================================================"
    echo "          PATH MANAGER FOR: $vps_name (IP: $ip)"
    echo "          Domain: $domain"
    echo "================================================================"
    
    if [ -f "$conf_file" ]; then
      echo "CURRENT PATHS:"
      local current_dom=""
      while read -r line; do
        if [[ "$line" == *"{"* ]] && [[ "$line" != *"reverse_proxy"* ]] && [[ "$line" != *"transport"* ]] && [[ "$line" != *"tls_"* ]]; then
          current_dom=$(echo "$line" | awk '{print $1}')
          current_dom=${current_dom%,}
        fi
        if [[ "$line" == *"reverse_proxy"* ]]; then
          local display_line="$line"
          if [[ "$line" == *"reverse_proxy /"* ]]; then
            display_line=$(echo "$line" | sed "s|reverse_proxy \(/[^ ]*\)|reverse_proxy https://$current_dom\1|")
          else
            display_line=$(echo "$line" | sed "s|reverse_proxy |reverse_proxy https://$current_dom/ |")
          fi
          display_line=$(echo "$display_line" | sed 's/^[ \t]*//')
          echo "- $display_line"
        fi
      done < "$conf_file"
      echo "----------------------------------------------------------------"
    fi

    echo "0) Back"
    echo "1) Add New Path"
    echo "2) Delete a Path"
    echo "3) Manual Advanced Edit (nano)"
    echo "4) Unlink Domain (Delete All Paths)"
    echo "================================================================"
    read -r -p "Choice [0=Back, Enter=1]: " choice
    choice="${choice:-1}"
    case "$choice" in
      0) break ;;
      1) add_path_to_vps "$vps_name" "$ip"; pause ;;
      2) delete_path_from_vps "$vps_name"; pause ;;
      3) 
        if [ -f "$conf_file" ]; then
          nano "$conf_file"
          echo "Validating..."
          caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1 && systemctl reload-or-restart caddy && echo "Reloaded successfully." || echo "Validation failed! Please fix errors."
        else
          echo "No config exists yet. Add a path first."
        fi
        pause
        ;;
      4)
        if [ -f "$conf_file" ]; then
          rm -f "$conf_file"
          systemctl reload-or-restart caddy
          echo "SUCCESS: Domain and all paths unlinked."
        fi
        pause
        ;;
      *) sleep 1 ;;
    esac
  done
}
