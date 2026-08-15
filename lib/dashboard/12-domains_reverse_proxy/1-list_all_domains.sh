#!/bin/bash

list_all_domains() {
  ensure_caddy_installed
  echo "=========================================================================="
  echo "                 ALL LINKED DOMAINS & PATHS"
  echo "=========================================================================="
  printf "%-15s %-25s %-15s %-15s\n" "VPS" "DOMAIN" "PATH" "TARGET"
  printf '%s\n' "--------------------------------------------------------------------------"
  
  local found=0
  for conf in "$CADDY_CONF_DIR"/*.caddy; do
    [ -e "$conf" ] || continue
    found=1
    local vps_name
    vps_name=$(basename "$conf" .caddy)
    local domain
    domain=$(head -n 1 "$conf" | awk '{print $1}')
    
    # Extract reverse_proxy lines with their domains
    local current_dom=""
    while read -r line; do
      if [[ "$line" == *"{"* ]] && [[ "$line" != *"reverse_proxy"* ]] && [[ "$line" != *"transport"* ]] && [[ "$line" != *"tls_"* ]]; then
        current_dom=$(echo "$line" | awk '{print $1}')
        current_dom=${current_dom%,}
      fi
      
      if [[ "$line" == *"reverse_proxy"* ]]; then
        # format: reverse_proxy /path/* https://ip:port
        local path_str="/"
        local target_str=""
        
        # Count words
        local words=($line)
        if [ "${#words[@]}" -ge 3 ] && [[ "${words[1]}" == *"/"* ]]; then
          path_str="${words[1]}"
          target_str="${words[2]}"
        else
          path_str="/"
          target_str="${words[1]}"
        fi
        
        printf "%-15s %-25s %-15s %-15s\n" "$vps_name" "$current_dom" "$path_str" "$target_str"
      fi
    done < "$conf"
  done

  if [ $found -eq 0 ]; then
    echo "No domains linked yet."
  fi
  echo "=========================================================================="
}
