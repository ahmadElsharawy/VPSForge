#!/bin/bash
# Print the secret token of a device's permanent subscription link, making one the first time.
# Tokens live on this server in $VPN_SUB_DIR/<public port>/tokens (name|token), so they survive
# key resets and SNI changes: the device's link stays the same, only what it returns changes.
#   vpn_sub_token <vps> <device>
vpn_sub_token() {
  local vps="${1:?vps}" name="${2:?device}" ext dir tok
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || return 1
  dir="$VPN_SUB_DIR/$ext"
  mkdir -p "$dir" && chmod 700 "$dir" || return 1
  touch "$dir/tokens" && chmod 600 "$dir/tokens"
  tok=$(awk -F'|' -v n="$name" '$1 == n { print $2; exit }' "$dir/tokens")
  if [ -z "$tok" ]; then
    tok=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
    echo "$name|$tok" >> "$dir/tokens"
  fi
  echo "$tok"
}
