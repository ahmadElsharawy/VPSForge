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

  # Setup import directory for vpsforge
  if [ ! -d "$CADDY_CONF_DIR" ]; then
    mkdir -p "$CADDY_CONF_DIR"
  fi

  # Ensure main Caddyfile imports our configs
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

list_domains() {
  ensure_caddy_installed
  echo "================================================================"
  echo "                 LINKED DOMAINS & PROXIES"
  echo "================================================================"
  printf "%-30s %-20s %-20s\n" "DOMAIN" "VPS TARGET" "INTERNAL IP"
  printf '%s\n' "----------------------------------------------------------------------"
  
  local found=0
  for conf in "$CADDY_CONF_DIR"/*.caddy; do
    [ -e "$conf" ] || continue
    found=1
    local domain
    local target_ip
    domain=$(head -n 1 "$conf" | awk '{print $1}')
    target_ip=$(grep "reverse_proxy" "$conf" | awk '{print $2}')
    local vps_name=$(basename "$conf" .caddy)
    
    printf "%-30s %-20s %-20s\n" "$domain" "$vps_name" "$target_ip"
  done

  if [ $found -eq 0 ]; then
    echo "No domains linked yet."
  fi
  echo "================================================================"
}

link_domain() {
  ensure_caddy_installed
  echo -n "Enter VPS Name to link (e.g. ${VPS_PREFIX}1): "
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

  echo -n "Enter Domain Name (e.g. app1.domain.com): "
  read -r domain
  if [ -z "$domain" ]; then
    echo "ERROR: Domain cannot be empty."
    sleep 2
    return
  fi

  local conf_file="$CADDY_CONF_DIR/${vps_name}.caddy"
  
  echo "$domain {" > "$conf_file"
  echo "    reverse_proxy $ip:80" >> "$conf_file"
  echo "}" >> "$conf_file"

  echo "Validating Caddy configuration..."
  if caddy validate --config "$MAIN_CADDYFILE" >/dev/null 2>&1; then
    systemctl reload caddy
    echo "SUCCESS: $domain is now securely routed to $vps_name ($ip:80)"
  else
    echo "ERROR: Invalid Caddy configuration generated."
    rm -f "$conf_file"
  fi
  echo "Press Enter to continue..."
  read -r
}

unlink_domain() {
  ensure_caddy_installed
  list_domains
  echo ""
  echo -n "Enter VPS Name to unlink its domain: "
  read -r vps_name
  
  local conf_file="$CADDY_CONF_DIR/${vps_name}.caddy"
  if [ -f "$conf_file" ]; then
    rm -f "$conf_file"
    systemctl reload caddy
    echo "SUCCESS: Domain unlinked for $vps_name."
  else
    echo "ERROR: No domain configuration found for $vps_name."
  fi
  echo "Press Enter to continue..."
  read -r
}

proxy_menu() {
  while true; do
    clear
    echo "================================================================"
    echo "                  DOMAINS & REVERSE PROXY (CADDY)"
    echo "================================================================"
    echo "1) List Linked Domains"
    echo "2) Link Domain to VPS"
    echo "3) Unlink Domain from VPS"
    echo "4) Back to Main Menu"
    echo "================================================================"
    echo -n "Select an option [1-4]: "
    read -r choice
    case "$choice" in
      1) list_domains; echo "Press Enter to continue..."; read -r ;;
      2) link_domain ;;
      3) unlink_domain ;;
      4) break ;;
      *) echo "Invalid option." ; sleep 1 ;;
    esac
  done
}
