#!/bin/bash
# Make a tunnel reachable from the internet: a Caddy route (domain) or a port forward (server port).
#   tunnel_public_start <vps> <tunnel_port> <public_port|""> <domain|"">
tunnel_public_start() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" ext="${3:-}" domain="${4:-}" ip route
  ip=$(get_ip "$vps")
  [ -n "$ip" ] || { echo "ERROR: $vps has no IP address."; return 1; }

  if [ -n "$domain" ]; then
    ensure_caddy_installed || return 1
    route=$(list_proxy_routes 2>/dev/null | awk -F'|' -v d="$domain" '$2 == d && $3 == "/" { print $1 "|" $4; exit }')
    if [ -n "$route" ]; then
      [[ "$route" == "$vps|"*":$tport" ]] && return 0
      echo "ERROR: $domain is already linked somewhere else (menu 12 > My domains). Remove that first or use another domain."
      return 1
    fi
    add_proxy_route "$vps" "$ip" "$domain" "" "$tport" "http"
    return $?
  fi

  if ! port_forward_rule_conflicts tcp 0.0.0.0 "$ext" "$ip" "$tport"; then
    if awk -F'|' -v p="$ext" -v ip="$ip" -v tp="$tport" '$3 == p && ($4 != ip || $5 != tp) { f = 1 } END { exit !f }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null; then
      echo "ERROR: public port $ext is already used by another forward."; return 1
    fi
    port_forward_host_conflict "$ext" tcp || return 1
  fi
  port_forward_apply_rule tcp 0.0.0.0 "$ext" "$ip" "$tport"
  port_forward_append_rule_to_file "$PORT_FORWARD_RULES_FILE" tcp 0.0.0.0 "$ext" "$ip" "$tport"
  save_iptables
  sync_vps_metadata "$vps"
}
