#!/bin/bash
# Forget a removed device's subscription: its token and file go, so its old link answers "not found".
#   vpn_sub_forget <vps> <device>
vpn_sub_forget() {
  local vps="${1:?vps}" name="${2:?device}" ext dir tok
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || return 0
  dir="$VPN_SUB_DIR/$ext"
  [ -f "$dir/tokens" ] || return 0
  tok=$(awk -F'|' -v n="$name" '$1 == n { print $2; exit }' "$dir/tokens")
  [ -n "$tok" ] || return 0
  rm -f "$dir/subs/$tok"
  awk -F'|' -v n="$name" '$1 != n' "$dir/tokens" > "$dir/tokens.new" && mv -f "$dir/tokens.new" "$dir/tokens"
  return 0
}
