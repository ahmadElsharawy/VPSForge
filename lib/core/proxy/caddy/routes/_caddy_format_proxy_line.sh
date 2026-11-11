#!/bin/bash
# Format a reverse_proxy directive with optional path and TLS skip-verify settings.
#   _caddy_format_proxy_line <url_path> <scheme> <ip> <port>
_caddy_format_proxy_line() {
  local url_path="${1:-}" scheme="${2:-http}" ip="$3" port="$4"
  local transport=""

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
    echo "    reverse_proxy $url_path ${scheme}://$ip:$port$transport"
  else
    echo "    reverse_proxy ${scheme}://$ip:$port$transport"
  fi
}
