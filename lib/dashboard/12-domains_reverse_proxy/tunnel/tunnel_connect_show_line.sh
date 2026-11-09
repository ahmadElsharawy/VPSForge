#!/bin/bash
# Prepare the limited login and show the ONE line to paste in PowerShell, with its password.
#   tunnel_connect_show_line <vps> <server_ip> <ssh_port> <tunnel_port> <local_port> [renew]
tunnel_connect_show_line() {
  local vps="${1:?vps}" host="${2:?host}" sshport="${3:?port}" tport="${4:?tunnel port}" lport="${5:?local port}" renew="${6:-}"
  echo
  if ! tunnel_access_prepare "$vps" "$host" "$sshport" "$tport" "$lport" "$renew"; then
    echo "ERROR: could not prepare the download inside $vps (is it running, with ssh installed?)."
    return 1
  fi
  echo "  Paste this ONE line in PowerShell on the Windows computer:"
  echo
  echo "  ssh -o StrictHostKeyChecking=accept-new -p ${sshport} ${TUNNEL_ACCESS_USER}@${host} | Out-String | iex"
  echo
  echo "  When it asks for a password, type:   ${TUNNEL_ACCESS_PASS}"
  echo
  echo "  It installs the tunnel: hidden, starts at every login, with a desktop on/off icon."
  echo "  SAFE TO SHARE: this login can only open port ${tport} on this VPS (no shell, no other access)."
  [ "$renew" = "renew" ] && echo "  Older setups no longer work."
  return 0
}
