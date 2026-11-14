#!/bin/bash
# Change the SNI of one protocol of a VPS's VPN and restart it.
# tls / hy also get a new self-signed certificate with the new name.
# Every device must import its links again (the links now show the new name).
#   vpn_set_sni <vps> <reality|tls|hy> <site>
vpn_set_sni() {
  local vps="${1:?vps}" kind="${2:?reality|tls|hy}" sni="${3:?site}" key files
  [ -n "$(vpn_get_port "$vps")" ] || { echo "ERROR: $vps has no VPN."; return 1; }
  sni="${sni,,}"
  is_valid_vpn_sni "$sni" || { echo "ERROR: '$sni' is not a site name (example: www.microsoft.com)."; return 1; }
  case "$kind" in
    reality)
      echo "Checking that $sni speaks TLS 1.3 and HTTP/2..."
      vpn_sni_supported "$sni" || { echo "ERROR: $sni does not answer with TLS 1.3 + HTTP/2 from this server."; return 1; }
      key="user.vpsforge.vpn_sni"; files="";;
    tls) key="user.vpsforge.vpn_tls_sni"; files="tls.key tls.crt";;
    hy)  key="user.vpsforge.vpn_hy_sni";  files="hy.key hy.crt";;
    *) echo "ERROR: protocol must be reality, tls or hy."; return 1;;
  esac
  incus config set "$vps" "$key" "$sni" || return 1
  if [ -n "$files" ]; then
    incus exec "$vps" --env D="$VPN_GUEST_DIR" --env F="$files" -- sh -c 'cd "$D" && rm -f $F' </dev/null || return 1
  fi
  vpn_server_setup "$vps"
}
