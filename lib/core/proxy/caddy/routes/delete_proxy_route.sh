#!/bin/bash
# Delete ONE route (identified by its line number in the VPS's Caddy file),
# including its nested "{ ... }" block. Exact: other routes are never touched.
# If it was the last route, the whole website is unlinked.
#   delete_proxy_route <vps> <line_number>
delete_proxy_route() {
  local vps="${1:?vps}" target_line="${2:?line}"
  local conf="$CADDY_CONF_DIR/${vps}.caddy" backup="${CADDY_CONF_DIR}/${1}.caddy.bak" domain
  [ -f "$conf" ] || return 1

  domain=$(grep -E '^[^[:space:]#].*\{[[:space:]]*$' "$conf" | head -n 1 | awk '{print $1}' | sed 's/[,{]//g')
  cp -f "$conf" "$backup"

  _caddy_remove_route_at_line "$conf" "$target_line"

  # a domain whose last route was just removed must not stay behind as an empty block
  local gone
  while IFS= read -r gone; do
    [ -n "$gone" ] && remove_domain_from_guest_hosts "$vps" "$gone"
  done < <(caddy_drop_empty_sites "$conf")

  if ! grep -q 'reverse_proxy' "$conf"; then
    rm -f "$backup"
    unlink_proxy_domain "$vps" "$domain"
    return 0
  fi

  if caddy_apply_or_rollback "$conf" "$backup"; then
    sync_vps_metadata "$vps"
    return 0
  fi
  sync_vps_metadata "$vps"
  return 1
}
