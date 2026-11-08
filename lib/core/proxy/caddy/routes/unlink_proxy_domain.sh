#!/bin/bash
# Remove a VPS's whole domain config (all its routes) and tidy up after it.
#   unlink_proxy_domain <vps> [domain]
unlink_proxy_domain() {
  local vps="${1:?vps}" domain="${2:-}" conf="$CADDY_CONF_DIR/${1}.caddy"
  if [ -z "$domain" ] && [ -f "$conf" ]; then
    domain=$(grep -E '^[^[:space:]#].*\{[[:space:]]*$' "$conf" | head -n 1 | awk '{print $1}' | sed 's/[,{]//g')
  fi
  rm -f "$conf" "${conf}.bak"
  systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  sync_vps_metadata "$vps"
  [ -n "$domain" ] && remove_domain_from_guest_hosts "$vps" "$domain"
  return 0
}
