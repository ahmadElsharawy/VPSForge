#!/bin/bash
# Delete the limited tunnel login of one tunnel port from a VPS (user, key, script and ssh rules). Safe to repeat.
#   tunnel_access_remove <vps> <tunnel_port>
tunnel_access_remove() {
  local vps="${1:?vps}" tport="${2:?tunnel port}"
  is_vps_running "$vps" || return 0
  incus exec "$vps" --env TUSER="$(tunnel_access_user "$tport")" --env TPORT="$tport" -- sh -c '
    # A tunnel that is still connected is cut first. Its processes take a moment to end,
    # and userdel refuses a user that still runs something, so try a few times.
    i=0
    while id "$TUSER" >/dev/null 2>&1 && [ "$i" -lt 10 ]; do
      pkill -KILL -u "$TUSER" >/dev/null 2>&1 || true
      userdel -f -r "$TUSER" >/dev/null 2>&1 || deluser --remove-home "$TUSER" >/dev/null 2>&1 || true
      id "$TUSER" >/dev/null 2>&1 && sleep 1
      i=$((i + 1))
    done
    rm -f "/etc/ssh/sshd_config.d/98-vpsforge-tunnel-$TPORT.conf" "/etc/vpsforge-tunnel/$TPORT.ps1" "/etc/vpsforge-tunnel/$TPORT.key" "/etc/vpsforge-tunnel/$TPORT.sh"
    systemctl try-reload-or-restart ssh >/dev/null 2>&1 || systemctl try-reload-or-restart sshd >/dev/null 2>&1 || service ssh reload >/dev/null 2>&1 || true
  ' </dev/null >/dev/null 2>&1
  return 0
}
