#!/bin/bash
# Make new keys for one protocol (or all) of a VPS's VPN and restart it. Devices keep their
# names, limits and usage, but their old links stop working: send each device its new link.
#   vpn_reset_keys <vps> <reality|tls|hy|all>
vpn_reset_keys() {
  local vps="${1:?vps}" kind="${2:?reality|tls|hy|all}" files
  [ -n "$(vpn_get_port "$vps")" ] || { echo "ERROR: $vps has no VPN."; return 1; }
  is_vps_running "$vps" || { echo "ERROR: $vps is not running."; return 1; }
  case "$kind" in
    reality) files="server.key server.pub short.id";;
    tls)     files="tls.key tls.crt";;
    hy)      files="hy.key hy.crt";;
    all)     files="server.key server.pub short.id tls.key tls.crt hy.key hy.crt";;
    *) echo "ERROR: choose reality, tls, hy or all."; return 1;;
  esac
  incus exec "$vps" --env D="$VPN_GUEST_DIR" --env F="$files" -- sh -c 'cd "$D" && rm -f $F' </dev/null || return 1
  vpn_server_setup "$vps"
}
