#!/bin/bash
# VPSForge — Delete reverse proxy path from VPS

delete_path_from_vps() {
  local vps_name="$1"
  local conf_file="$CADDY_CONF_DIR/${vps_name}.caddy"
  
  if [ ! -f "$conf_file" ]; then
    echo "No routes exist for VPS '$vps_name'."
    sleep 2
    return
  fi

  echo "Current paths for $vps_name:"
  local -a proxy_lines=() raw_lines=()
  local i=1
  local current_dom=""

  while IFS= read -r line; do
    local trimmed
    trimmed=$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
    if [[ "$trimmed" == *"{"* ]] && [[ "$trimmed" != *"reverse_proxy"* ]] && [[ "$trimmed" != *"transport"* ]] && [[ "$trimmed" != *"tls_"* ]]; then
      current_dom=$(echo "$trimmed" | awk '{print $1}')
      current_dom=${current_dom%,}
      current_dom=${current_dom%\{}
    fi
    if [[ "$trimmed" == "reverse_proxy"* ]]; then
      raw_lines[$i]="$line"
      proxy_lines[$i]="$trimmed"
      local display_line="$trimmed"
      if [[ "$trimmed" == *"reverse_proxy /"* ]]; then
        display_line=$(echo "$trimmed" | sed "s|reverse_proxy \(/[^ ]*\)|reverse_proxy https://$current_dom\1|")
      else
        display_line=$(echo "$trimmed" | sed "s|reverse_proxy |reverse_proxy https://$current_dom/ |")
      fi
      echo "$i) $display_line"
      ((i++))
    fi
  done < "$conf_file"

  local total_paths=$((i - 1))
  if [ "$total_paths" -eq 0 ]; then
    echo "No reverse proxy paths found in configuration."
    rm -f "$conf_file" 2>/dev/null || true
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
    sync_vps_metadata "$vps_name"
    sleep 2
    return
  fi

  read -r -p "Enter path number to delete (or 0 to cancel): " choice </dev/tty
  [ "${choice:-0}" = "0" ] && return
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$total_paths" ]; then
    echo "Invalid path number."
    return
  fi

  local target_raw="${raw_lines[$choice]}"
  local target_trimmed="${proxy_lines[$choice]}"

  # Reconstruct file omitting the selected path (and any nested transport block)
  local -a new_lines=()
  local deleting=0 brace_depth=0

  while IFS= read -r line; do
    local trimmed
    trimmed=$(echo "$line" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')

    if [ $deleting -eq 1 ]; then
      local open_b=$(echo "$line" | tr -cd '{' | wc -c)
      local close_b=$(echo "$line" | tr -cd '}' | wc -c)
      brace_depth=$((brace_depth + open_b - close_b))
      if [ $brace_depth -le 0 ]; then
        deleting=0
      fi
      continue
    fi

    # Match trimmed line prefix
    if [ "$trimmed" = "$target_trimmed" ] || [[ "$trimmed" == "$target_trimmed"* ]]; then
      local open_b=$(echo "$line" | tr -cd '{' | wc -c)
      local close_b=$(echo "$line" | tr -cd '}' | wc -c)
      brace_depth=$((open_b - close_b))
      if [ $brace_depth -gt 0 ]; then
        deleting=1
      fi
      continue
    fi

    new_lines+=("$line")
  done < "$conf_file"

  printf "%s\n" "${new_lines[@]}" > "$conf_file"

  # Clean up empty domain blocks if no reverse_proxy remains in the file
  if ! grep -q "reverse_proxy" "$conf_file" 2>/dev/null; then
    rm -f "$conf_file"
    echo "All paths removed. Domain configuration removed automatically."
  else
    python3 -c "
import sys, re, os
try:
    with open('$conf_file', 'r') as f:
        content = f.read()
    cleaned = re.sub(r'[a-zA-Z0-9.-]+\s*\{\s*\}', '', content)
    cleaned = re.sub(r'\n\s*\n\s*\n', '\n\n', cleaned).strip() + '\n'
    if 'reverse_proxy' not in cleaned:
        os.remove('$conf_file')
    else:
        with open('$conf_file', 'w') as f:
            f.write(cleaned)
except Exception:
    pass
" 2>/dev/null || true
  fi

  if [ -f "$conf_file" ]; then
    if caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1; then
      systemctl reload-or-restart caddy >/dev/null 2>&1 || true
      sync_vps_metadata "$vps_name"
      echo "SUCCESS: Selected path was deleted successfully."
    else
      echo "ERROR: Configuration validation failed after deletion."
      echo "Opening in nano to review..."
      sleep 2
      nano "$conf_file"
      systemctl reload-or-restart caddy >/dev/null 2>&1 || true
      sync_vps_metadata "$vps_name"
    fi
  else
    systemctl reload-or-restart caddy >/dev/null 2>&1 || true
    sync_vps_metadata "$vps_name"
    echo "SUCCESS: Path deleted and domain unlinked."
  fi
}
