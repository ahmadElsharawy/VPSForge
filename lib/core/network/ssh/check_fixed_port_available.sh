#!/bin/bash
# Is <port> free to be the SSH port of <name>? Not when another VPS's forward uses it, and not
# when a program on the server itself listens on it (the forward would silently take its place).
#   check_fixed_port_available <name> <ip> <port>
check_fixed_port_available() {
  local name="$1" ip="$2" port="$3" owner_ip
  # POSIX awk only (Ubuntu ships mawk, which has no 3-arg match()).
  owner_ip=$(iptables -t nat -L PREROUTING -n 2>/dev/null | awk -v p="$port" '
    $0 ~ ("dpt:" p "([^0-9]|$)") {
      if (match($0, /to:[0-9.]+:[0-9]+/)) {
        s = substr($0, RSTART + 3, RLENGTH - 3)
        sub(/:[0-9]+$/, "", s)
        print s
      }
      exit
    }' 2>/dev/null || true)

  if [ -n "$owner_ip" ] && [ "$owner_ip" != "$ip" ]; then
    echo "ERROR: Required port $port for $name is already assigned to $owner_ip."
    return 1
  fi
  local host_owner
  host_owner=$(host_port_owner "$port" tcp 2>/dev/null || true)
  if [ -z "$owner_ip" ] && [ -n "$host_owner" ]; then
    echo "ERROR: port $port for $name is already used on this server by '$host_owner'."
    return 1
  fi
  return 0
}
