#!/bin/bash
# Retrieve public IPv4 address with local file caching; pass "force" to bypass cache.
get_public_ip() {
  local force="${1:-}" now cache_mtime ip
  now=$(date +%s)

  if [ "$force" != "force" ] && [ -s "$PUBLIC_IP_CACHE_FILE" ]; then
    cache_mtime=$(stat -c %Y "$PUBLIC_IP_CACHE_FILE" 2>/dev/null || echo 0)
    if [ $((now - cache_mtime)) -lt "$PUBLIC_IP_TTL" ]; then
      PUBLIC_IP=$(cat "$PUBLIC_IP_CACHE_FILE" 2>/dev/null)
      [ -n "$PUBLIC_IP" ] && return 0
    fi
  fi

  ip=$(curl -4 -fsS --max-time 3 https://api.ipify.org 2>/dev/null || true)
  if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    PUBLIC_IP="$ip"
    mkdir -p "$(dirname "$PUBLIC_IP_CACHE_FILE")" 2>/dev/null || true
    printf '%s' "$ip" > "$PUBLIC_IP_CACHE_FILE" 2>/dev/null || true
  elif [ -s "$PUBLIC_IP_CACHE_FILE" ]; then
    PUBLIC_IP=$(cat "$PUBLIC_IP_CACHE_FILE" 2>/dev/null)
  else
    PUBLIC_IP="Unknown"
  fi
}
