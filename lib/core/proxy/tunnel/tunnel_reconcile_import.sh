#!/bin/bash
# After a VPS came back from a backup (new IP, maybe a changed public port or a skipped forward), make its tunnel
# records tell the truth: a tunnel is "active" only if its public side really came back. The limited login keeps
# its key, but its setup script is renewed because it holds the server address and the VPS ssh port.
#   tunnel_reconcile_import <vps> <new_ip> <new_ssh_port> [renew]   (renew = new key: a copy must not share the original's key)
tunnel_reconcile_import() {
  local vps="${1:?vps}" ip="${2:?ip}" sshport="${3:?ssh port}" renew="${4:-}" rec tport lport ext domain state new_ext new_state
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    IFS='|' read -r tport lport ext domain state <<< "$rec"
    new_ext="$ext"; new_state="stopped"
    if [ -n "$domain" ]; then
      list_proxy_routes 2>/dev/null | awk -F'|' -v v="$vps" -v d="$domain" '$1 == v && $2 == d { f = 1 } END { exit !f }' && new_state="active"
    else
      new_ext=$(awk -F'|' -v ip="$ip" -v p="$tport" '$4 == ip && $5 == p { print $3; exit }' "$PORT_FORWARD_RULES_FILE" 2>/dev/null)
      if [ -n "$new_ext" ]; then new_state="active"; else new_ext="$ext"; fi
    fi
    tunnel_record_set "$vps" "$tport" "$lport" "$new_ext" "$domain" "$new_state"
    if incus exec "$vps" --env TPORT="$tport" -- sh -c 'test -f "/etc/vpsforge-tunnel/$TPORT.key"' </dev/null >/dev/null 2>&1; then
      tunnel_access_prepare "$vps" "${PUBLIC_IP:-SERVER-IP}" "$sshport" "$tport" "$lport" "$renew" >/dev/null 2>&1 || true
    fi
  done < <(tunnel_get_records "$vps")
  return 0
}
