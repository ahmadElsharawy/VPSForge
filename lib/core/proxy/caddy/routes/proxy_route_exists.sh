#!/bin/bash
# Succeeds (and says where) when this exact website route already exists for any VPS.
#   proxy_route_exists <domain> <path|"">
proxy_route_exists() {
  local domain="${1:?domain}" url_path="${2:-}" normalized line owner
  if [ -z "$url_path" ] || [ "$url_path" = "/" ]; then
    normalized="/"
  else
    [[ "$url_path" != /* ]] && url_path="/$url_path"
    if [[ "$url_path" != *\* ]]; then
      [[ "$url_path" == */ ]] && url_path="${url_path}*" || url_path="${url_path}/*"
    fi
    normalized="$url_path"
  fi
  line=$(list_proxy_routes 2>/dev/null | awk -F'|' -v d="$domain" -v p="$normalized" '$2==d && $3==p {print; exit}')
  [ -n "$line" ] || return 1
  owner=$(echo "$line" | cut -d'|' -f1)
  echo "CONFLICT: https://${domain}${normalized%\*} is already linked (VPS $owner). Remove it first (menu 12 > My domains) or choose another domain or folder."
  return 0
}
