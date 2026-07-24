#!/bin/bash
# VPSForge — Caddy Reverse Proxy & Domain Management

CADDY_CONF_DIR="/etc/caddy/vpsforge"
MAIN_CADDYFILE="/etc/caddy/Caddyfile"

ensure_caddy_installed() {
  if ! command -v caddy &> /dev/null; then
    echo "Installing Caddy Reverse Proxy (HTTPS auto-ssl)..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
    apt-get update -y >/dev/null 2>&1
    apt-get install caddy -y >/dev/null 2>&1
    systemctl enable --now caddy >/dev/null 2>&1
    echo "Caddy installed successfully."
  fi

  if [ ! -d "$CADDY_CONF_DIR" ]; then
    mkdir -p "$CADDY_CONF_DIR"
  fi

  if [ -f "$MAIN_CADDYFILE" ]; then
    if ! grep -q "import /etc/caddy/vpsforge/\*.caddy" "$MAIN_CADDYFILE"; then
      echo -e "\nimport /etc/caddy/vpsforge/*.caddy" >> "$MAIN_CADDYFILE"
      systemctl reload caddy >/dev/null 2>&1 || true
    fi
  else
    echo "import /etc/caddy/vpsforge/*.caddy" > "$MAIN_CADDYFILE"
    systemctl restart caddy >/dev/null 2>&1 || true
  fi
}

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
    
    # Extract reverse_proxy lines
    while read -r line; do
      if [[ "$line" == *"reverse_proxy"* ]]; then
        # format: reverse_proxy /path/* https://ip:port
        local path_str="/"
        local target_str=""
        
        # Count words
        local words=($line)
        if [ "${#words[@]}" -ge 3 ]; then
          path_str="${words[1]}"
          target_str="${words[2]}"
        else
          path_str="/"
          target_str="${words[1]}"
        fi
        
        printf "%-15s %-25s %-15s %-15s\n" "$vps_name" "$domain" "$path_str" "$target_str"
      fi
    done < "$conf"
  done

  if [ $found -eq 0 ]; then
    echo "No domains linked yet."
  fi
  echo "=========================================================================="
}

add_path_to_vps() {
  local vps_name="$1"
  local ip="$2"
  local conf_file="$CADDY_CONF_DIR/${vps_name}.caddy"
  local domain=""

  if [ ! -f "$conf_file" ]; then
    echo -n "Enter Domain Name for this VPS (e.g. app1.domain.com): "
    read -r domain
    if [ -z "$domain" ]; then
      echo "ERROR: Domain cannot be empty."
      sleep 2
      return
    fi
    echo "$domain {" > "$conf_file"
    echo "}" >> "$conf_file"
  else
    domain=$(head -n 1 "$conf_file" | awk '{print $1}')
    echo "Using existing domain for this VPS: $domain"
  fi

  echo -n "Enter Path (e.g. /sub/ or leave empty for root '/'): "
  read -r url_path
  if [ -z "$url_path" ] || [ "$url_path" = "/" ]; then
    url_path=""
  else
    [[ "$url_path" != /* ]] && url_path="/$url_path"
    [[ "$url_path" != */* ]] && url_path="$url_path*"
  fi

  echo -n "Enter target port inside VPS [Default: 80]: "
  read -r target_port
  if [ -z "$target_port" ]; then
    target_port="80"
  fi

  echo -n "Is the target using HTTPS internally? (y/N): "
  read -r use_https
  
  local target_schema="http"
  local caddy_transport=""
  if [[ "$use_https" =~ ^[Yy]$ ]]; then
    target_schema="https"
    caddy_transport=" {
        transport http {
            tls_insecure_skip_verify
        }
    }"
  fi

  # Remove closing bracket, append, re-add closing bracket
  sed -i '$ d' "$conf_file"
  
  if [ -n "$url_path" ]; then
    echo "    reverse_proxy $url_path ${target_schema}://$ip:$target_port$caddy_transport" >> "$conf_file"
  else
    echo "    reverse_proxy ${target_schema}://$ip:$target_port$caddy_transport" >> "$conf_file"
  fi
  
  echo "}" >> "$conf_file"

  echo "Validating Caddy configuration..."
  if caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1; then
    systemctl reload caddy
    echo "SUCCESS: $domain$url_path is now securely routed to $vps_name (${target_schema}://$ip:$target_port)"
  else
    echo "ERROR: Invalid configuration! Opening file in nano so you can fix it manually..."
    sleep 2
    nano "$conf_file"
    systemctl reload caddy >/dev/null 2>&1 || true
  fi
}

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
  while read -r line; do
    if [[ "$line" == *"reverse_proxy"* ]]; then
      echo "$i) $line"
      lines[$i]="$line"
      ((i++))
    fi
  done < "$conf_file"

  if [ ${#lines[@]} -eq 0 ]; then
    echo "No paths found."
    sleep 2
    return
  fi

  echo -n "Enter the number of the path to delete (or leave empty to cancel): "
  read -r choice
  if [ -n "$choice" ] && [ -n "${lines[$choice]:-}" ]; then
    # Delete the specific line from the file
    local escaped_line=$(printf '%s\n' "${lines[$choice]}" | sed -e 's/[]\/$*.^|[]/\\&/g')
    sed -i "/$escaped_line/d" "$conf_file"
    
    # If the file now only contains the domain and "}", it's basically empty. 
    # Let's count lines
    local line_count=$(wc -l < "$conf_file")
    if [ "$line_count" -le 2 ]; then
      rm -f "$conf_file"
      echo "No paths left. Domain unlinked automatically."
    fi

    systemctl reload caddy
    echo "SUCCESS: Path deleted."
  else
    echo "Cancelled."
  fi
}

manage_vps_proxy() {
  ensure_caddy_installed
  echo -n "Enter VPS Name to manage its paths (e.g. ${VPS_PREFIX}1): "
  read -r vps_name
  if ! incus info "$vps_name" >/dev/null 2>&1; then
    echo "ERROR: VPS '$vps_name' does not exist."
    sleep 2
    return
  fi

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
      grep "reverse_proxy" "$conf_file" | sed 's/^[ \t]*//' | sed 's/^/- /'
      echo "----------------------------------------------------------------"
    fi

    echo "1) Add New Path"
    echo "2) Delete a Path"
    echo "3) Manual Advanced Edit (nano)"
    echo "4) Unlink Domain (Delete All Paths)"
    echo "5) Back"
    echo "================================================================"
    echo -n "Select an option [1-5]: "
    read -r choice
    case "$choice" in
      1) add_path_to_vps "$vps_name" "$ip"; echo "Press Enter..."; read -r ;;
      2) delete_path_from_vps "$vps_name"; echo "Press Enter..."; read -r ;;
      3) 
        if [ -f "$conf_file" ]; then
          nano "$conf_file"
          echo "Validating..."
          caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1 && systemctl reload caddy && echo "Reloaded successfully." || echo "Validation failed! Please fix errors."
        else
          echo "No config exists yet. Add a path first."
        fi
        echo "Press Enter..."; read -r
        ;;
      4)
        if [ -f "$conf_file" ]; then
          rm -f "$conf_file"
          systemctl reload caddy
          echo "SUCCESS: Domain and all paths unlinked."
        fi
        echo "Press Enter..."; read -r
        ;;
      5) break ;;
      *) sleep 1 ;;
    esac
  done
}

proxy_menu() {
  while true; do
    clear
    echo "================================================================"
    echo "                  DOMAINS & REVERSE PROXY (CADDY)"
    echo "================================================================"
    echo "1) List All Linked Domains & Paths"
    echo "2) Manage Paths for a VPS (Add/Delete/Edit)"
    echo "3) Back to Main Menu"
    echo "================================================================"
    echo -n "Select an option [1-3]: "
    read -r choice
    case "$choice" in
      1) list_all_domains; echo "Press Enter to continue..."; read -r ;;
      2) manage_vps_proxy ;;
      3) break ;;
      *) echo "Invalid option." ; sleep 1 ;;
    esac
  done
}
