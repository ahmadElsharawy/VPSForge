#!/bin/bash
# Remove a VPS's whole domain config (all its routes) and tidy up after it.
#   unlink_proxy_domain <vps> [domain]
unlink_proxy_domain() {
  local vps="${1:?vps}" domain="${2:-}" conf="$CADDY_CONF_DIR/${1}.caddy" d
  local -a domains=()
  if [ -n "$domain" ]; then
    domains=("$domain")
  elif [ -f "$conf" ]; then
    # every site of the file: several blocks, and several names on one line ("a.com, b.com {")
    mapfile -t domains < <(grep -E '^[^[:space:]#].*\{[[:space:]]*$' "$conf" | sed 's/{.*//' | tr ', ' '\n\n' | grep -v '^$' | sort -u)
  fi
  rm -f "$conf" "${conf}.bak"
  systemctl reload-or-restart caddy >/dev/null 2>&1 || true
  sync_vps_metadata "$vps"
  for d in "${domains[@]}"; do
    remove_domain_from_guest_hosts "$vps" "$d"
  done
  return 0
}
