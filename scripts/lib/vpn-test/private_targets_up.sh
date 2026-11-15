#!/bin/bash
# Start the small web servers the private-access test aims at: one in the device VPS, one on this
# server's bridge address. private_targets_down stops them.
private_targets_up() {
  in_c 'nohup python3 -m http.server 18998 --bind 0.0.0.0 >/dev/null 2>&1 & sleep 1'
  ( cd /tmp && setsid python3 -m http.server 18997 --bind "$INCUS_GATEWAY" >/dev/null 2>&1 & )
  iptables -I INPUT 1 -s "$SIP" -d "$INCUS_GATEWAY" -p tcp --dport 18997 -j ACCEPT
  sleep 1
}
