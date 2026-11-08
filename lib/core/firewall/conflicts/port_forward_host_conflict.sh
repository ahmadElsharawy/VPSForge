#!/bin/bash
# Before opening <port>: does the server itself (or Caddy/websites) already use it?
# A port-forward catches the traffic BEFORE the server's own program, so it would silently
# take that program's place. Prints what conflicts and returns:
#   0 = no conflict, 1 = must not be done (it would lock you out), 2 = conflict, ask the user.
#   port_forward_host_conflict <port> <tcp|udp|both>
port_forward_host_conflict() {
  local port="${1:?port}" protocol="${2:-tcp}" proto owner status=0 ssh_port
  ssh_port=$(ss -H -ltnp 2>/dev/null | awk '/sshd/ {n=split($4,a,":"); print a[n]; exit}')

  if [ "$port" = "${ssh_port:-22}" ] || [ "$port" = "22" ]; then
    echo "CONFLICT: port $port is the SSH port of this server. Forwarding it would lock you out of the server."
    return 1
  fi

  for proto in $(resolve_protocols "$protocol"); do
    owner=$(host_port_owner "$port" "$proto")
    if [ -n "$owner" ]; then
      echo "CONFLICT: port $port ($proto) is already used on this server by '$owner'. The forward would take its place and that program would stop answering."
      status=2
    fi
  done

  if [ "$port" = "80" ] || [ "$port" = "443" ]; then
    if command -v caddy >/dev/null 2>&1 && [ -n "$(list_proxy_routes 2>/dev/null)" ]; then
      echo "CONFLICT: ports 80/443 are used by your domains (Caddy). A forward here would break them."
      status=2
    fi
  fi
  return "$status"
}
