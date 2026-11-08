#!/bin/bash
# Print the name of the program on THIS SERVER that already listens on a port (empty when free).
#   host_port_owner <port> <tcp|udp>
host_port_owner() {
  local port="${1:?port}" proto="${2:-tcp}" flag="-ltnp" line
  [ "$proto" = "udp" ] && flag="-lunp"
  line=$(ss -H $flag "( sport = :$port )" 2>/dev/null | head -n 1)
  [ -n "$line" ] || return 0
  echo "$line" | grep -oE 'users:\(\("[^"]+"' | head -n 1 | cut -d'"' -f2
  echo "$line" | grep -q 'users:' || echo "another program"
}
