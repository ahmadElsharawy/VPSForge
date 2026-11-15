#!/bin/bash
# Stop the web servers started by private_targets_up and close their firewall opening.
private_targets_down() {
  local p
  in_c 'pkill -f "[h]ttp.server 18998"' >/dev/null 2>&1
  p=$(pgrep -f "[h]ttp.server 18997"); [ -n "$p" ] && kill $p
  iptables -D INPUT -s "$SIP" -d "$INCUS_GATEWAY" -p tcp --dport 18997 -j ACCEPT 2>/dev/null
  return 0
}
