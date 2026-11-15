#!/bin/bash
# Rewrite the subscription files of every device of one VPN (links + days and GB left), so each
# permanent link returns what is true now, and make sure the small web server that answers them runs.
# Cheap enough for the 5-minute cron: two incus calls per VPN, whatever the number of devices.
# File $VPN_SUB_DIR/<port>/subs/<token>: line 1 "upload=..; download=..; total=..; expire=..", line 2 the
# name, then the links. A switched-off device keeps its file (its name then shows 0d or 0GB).
#   vpn_sub_refresh <vps>
vpn_sub_refresh() {
  local vps="${1:?vps}" ext dir keys pub sid sni tls_sni hy_sni hy_port
  local name id used limit expires tok label total tmp
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || return 0
  is_vps_running "$vps" || return 0
  dir="$VPN_SUB_DIR/$ext"
  mkdir -p "$dir/subs" "$dir/pages" && chmod 700 "$dir" || return 1
  [ -n "${PUBLIC_IP:-}" ] || get_public_ip >/dev/null 2>&1
  keys=$(incus exec "$vps" --env D="$VPN_GUEST_DIR" -- sh -c 'cat "$D/server.pub" "$D/short.id"' </dev/null 2>/dev/null) || return 1
  pub=$(sed -n 1p <<< "$keys"); sid=$(sed -n 2p <<< "$keys")
  [ -n "$pub" ] && [ -n "$sid" ] || return 1
  sni=$(vpn_get_sni "$vps"); tls_sni=$(vpn_get_sni "$vps" tls); hy_sni=$(vpn_get_sni "$vps" hy)
  hy_port=$(vpn_get_hy_port "$vps")
  while IFS='|' read -r name id _ _ used limit expires _; do
    [ -n "$name" ] && [ -n "$id" ] || continue
    tok=$(vpn_sub_token "$vps" "$name") || continue
    label=$(_vpn_label_from "$vps" "$used" "$limit" "$expires")
    total=0
    [ "${limit:-0}" -gt 0 ] && total=$((limit * 1073741824))
    tmp="$dir/subs/.$tok.new"
    {
      echo "upload=0; download=${used:-0}; total=${total}; expire=${expires:-0}"
      echo "$label"
      _vpn_links_from "$id" "$pub" "$sid" "$label" "$ext" "$sni" "$tls_sni" "$hy_sni" "$hy_port"
    } > "$tmp" && mv -f "$tmp" "$dir/subs/$tok"
  done < <(vpn_list_devices "$vps")
  vpn_sub_server_ensure "$vps"
}
