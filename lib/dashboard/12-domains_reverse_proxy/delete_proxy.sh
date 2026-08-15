#!/bin/bash

delete_path_from_vps() {
  local vps_name="$1"
  local conf_file="$CADDY_CONF_DIR/${vps_name}.caddy"
  
  if [ ! -f "$conf_file" ]; then
    echo "No routes exist for VPS '$vps_name'."
    sleep 2
    return
  fi

  echo "Current paths for $vps_name:"
  local -a lines=()
  local i=1
  local current_dom=""
  while read -r line; do
    if [[ "$line" == *"{"* ]] && [[ "$line" != *"reverse_proxy"* ]] && [[ "$line" != *"transport"* ]] && [[ "$line" != *"tls_"* ]]; then
      current_dom=$(echo "$line" | awk '{print $1}')
      current_dom=${current_dom%,}
    fi
    if [[ "$line" == *"reverse_proxy"* ]]; then
      lines[$i]="$line"
      local display_line="$line"
      if [[ "$line" == *"reverse_proxy /"* ]]; then
        display_line=$(echo "$line" | sed "s|reverse_proxy \(/[^ ]*\)|reverse_proxy https://$current_dom\1|")
      else
        display_line=$(echo "$line" | sed "s|reverse_proxy |reverse_proxy https://$current_dom/ |")
      fi
      display_line=$(echo "$display_line" | sed 's/^[ \t]*//')
      echo "$i) $display_line"
      ((i++))
    fi
  done < "$conf_file"

  if [ ${#lines[@]} -eq 0 ]; then
    echo "No paths found."
    sleep 2
    return
  fi

  read -r -p "Enter path number to delete (or 0 to cancel): " choice
  [ "$choice" = "0" ] && return
  if [ -n "$choice" ] && [ -n "${lines[$choice]:-}" ]; then
    local target_line="${lines[$choice]}"
    local -a new_lines=()
    local deleting=0
    local brace_count=0

    while IFS= read -r line; do
      if [ $deleting -eq 1 ]; then
        local open_b=$(echo "$line" | tr -cd '{' | wc -c)
        local close_b=$(echo "$line" | tr -cd '}' | wc -c)
        brace_count=$((brace_count + open_b - close_b))
        if [ $brace_count -le 0 ]; then
          deleting=0
        fi
        continue
      fi

      if [[ "$line" == "$target_line"* ]]; then
        deleting=1
        local open_b=$(echo "$line" | tr -cd '{' | wc -c)
        local close_b=$(echo "$line" | tr -cd '}' | wc -c)
        brace_count=$((open_b - close_b))
        if [ $brace_count -le 0 ]; then
          deleting=0
        fi
        continue
      fi

      new_lines+=("$line")
    done < "$conf_file"

    printf "%s\n" "${new_lines[@]}" > "$conf_file"
    
    local line_count=$(wc -l < "$conf_file")
    if [ "$line_count" -le 2 ]; then
      rm -f "$conf_file"
      echo "No paths left. Domain unlinked automatically."
    fi

    if caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1; then
      systemctl reload-or-restart caddy >/dev/null 2>&1 || true
      echo "SUCCESS: Path deleted."
    else
      echo "ERROR: Failed to delete path cleanly. Please use 'Manual Advanced Edit' or 'Unlink Domain' to fix the file."
    fi
  else
    echo "Cancelled."
  fi
}
