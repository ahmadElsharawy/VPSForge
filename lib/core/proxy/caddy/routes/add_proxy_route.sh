#!/bin/bash
# Add one website route: https://<domain><path> -> <scheme>://<vps ip>:<port>
# Non-interactive (the menus and tests both call this). The config is validated
# first; if Caddy rejects it, the previous file is restored.
#   add_proxy_route <vps> <ip> <domain> <path|""> <port> <http|https>
add_proxy_route() {
  local vps="${1:?vps}" ip="${2:?ip}" domain="${3:?domain}" url_path="${4:-}" port="${5:?port}" scheme="${6:-http}"
  local conf="$CADDY_CONF_DIR/${vps}.caddy" backup="" other_owner proxy_line transport=""

  if ! [[ "$domain" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
    echo "ERROR: '$domain' is not a valid domain name."; return 1
  fi
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo "ERROR: '$port' is not a valid port."; return 1
  fi
  if [ -n "$url_path" ] && ! [[ "$url_path" =~ ^[A-Za-z0-9/_.*-]+$ ]]; then
    echo "ERROR: the path may only contain letters, digits and / _ . - *"; return 1
  fi
  if other_owner=$(domain_used_by_other_vps "$domain" "$vps"); then
    echo "ERROR: $domain is already used by '$other_owner'. Remove it there first."; return 1
  fi

  if proxy_route_exists "$domain" "$url_path"; then
    return 1
  fi

  # "/api" or "/api/" -> "/api/*"; "/" or empty -> whole website
  if [ -z "$url_path" ] || [ "$url_path" = "/" ]; then
    url_path=""
  else
    [[ "$url_path" != /* ]] && url_path="/$url_path"
    if [[ "$url_path" != *\* ]]; then
      [[ "$url_path" == */ ]] && url_path="${url_path}*" || url_path="${url_path}/*"
    fi
  fi

  if [ "$scheme" = "https" ]; then
    transport=" {
        transport http {
            tls_insecure_skip_verify
        }
    }"
  else
    scheme="http"
  fi

  if [ -n "$url_path" ]; then
    proxy_line="    reverse_proxy $url_path ${scheme}://$ip:$port$transport"
  else
    proxy_line="    reverse_proxy ${scheme}://$ip:$port$transport"
  fi

  mkdir -p "$CADDY_CONF_DIR"
  if [ -f "$conf" ]; then
    backup="${conf}.bak"
    cp -f "$conf" "$backup"
  fi

  if [ ! -f "$conf" ]; then
    printf '%s {\n%s\n}\n' "$domain" "$proxy_line" > "$conf"
  else
    local -a new_lines=()
    local in_domain=0 brace_count=0 inserted=0 line open_b close_b
    while IFS= read -r line; do
      if [ $inserted -eq 0 ]; then
        if [ $in_domain -eq 1 ]; then
          open_b=$(echo "$line" | tr -cd '{' | wc -c)
          close_b=$(echo "$line" | tr -cd '}' | wc -c)
          brace_count=$((brace_count + open_b - close_b))
          if [ $brace_count -le 0 ]; then
            new_lines+=("$proxy_line")
            inserted=1
          fi
        elif [[ "$line" == "$domain {"* ]] || [[ "$line" == "$domain,"* ]]; then
          in_domain=1
          brace_count=1
        fi
      fi
      new_lines+=("$line")
    done < "$conf"
    if [ $inserted -eq 0 ]; then
      new_lines+=("" "$domain {" "$proxy_line" "}")
    fi
    printf '%s\n' "${new_lines[@]}" > "$conf"
  fi

  if ! caddy_apply_or_rollback "$conf" "$backup"; then
    sync_vps_metadata "$vps"
    return 1
  fi

  incus exec "$vps" --env DOMAIN="$domain" -- sh -c 'grep -qxF "127.0.0.1 $DOMAIN" /etc/hosts || echo "127.0.0.1 $DOMAIN" >> /etc/hosts' 2>/dev/null || true
  sync_vps_metadata "$vps"
  return 0
}
