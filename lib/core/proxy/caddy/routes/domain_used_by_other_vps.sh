#!/bin/bash
# Succeeds (and prints the owner) when <domain> is already linked to a VPS other than <vps_name>.
#   domain_used_by_other_vps <domain> <vps_name>
domain_used_by_other_vps() {
  local domain="${1:?domain}" self="${2:?vps_name}" file owner
  for file in "$CADDY_CONF_DIR"/*.caddy; do
    [ -e "$file" ] || continue
    owner=$(basename "$file" .caddy)
    [ "$owner" = "$self" ] && continue
    if grep -E '^[^[:space:]#].*\{[[:space:]]*$' "$file" | tr -d '{' | tr ',' ' ' | tr -s ' ' '\n' | grep -qxF "$domain"; then
      echo "$owner"
      return 0
    fi
  done
  return 1
}
