#!/bin/bash
# Test connectivity to the backend application container and diagnose binding issues.
#   _diagnose_backend_connectivity <vps_name> <target_schema> <ip> <target_port>
_diagnose_backend_connectivity() {
  local vps_name="$1" target_schema="$2" ip="$3" target_port="$4"
  echo -n "[2/4] Testing Backend Connection (${target_schema}://$ip:$target_port)... "
  if ! is_vps_running "$vps_name"; then
    echo "FAILED (Container Stopped)"
    echo "  ⚠️  VPS container '$vps_name' is currently STOPPED!"
    echo "     Caddy cannot reach a stopped container and will return 502 Bad Gateway."
    echo "     👉 FIX: Start '$vps_name' from Main Menu -> 3) Start."
    return 1
  fi

  local backend_ok=0
  if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$ip/$target_port" 2>/dev/null; then
    backend_ok=1
  elif curl -s -m 2 -k "${target_schema}://$ip:$target_port" >/dev/null 2>&1; then
    backend_ok=1
  fi

  if [ "$backend_ok" -eq 1 ]; then
    echo "OK (Backend is reachable & responding)"
    return 0
  fi

  echo "FAILED (Connection Refused / Unreachable)"

  local listening_info=""
  listening_info=$(incus exec "$vps_name" -- sh -c "(ss -lnt || netstat -lnt) 2>/dev/null" | grep -E "[:.]${target_port}([[:space:]]|$)" || true)

  if [ -n "$listening_info" ]; then
    if echo "$listening_info" | grep -qE "(127\.0\.0\.1|::1|localhost)"; then
      echo "  ⚠️  CRITICAL BINDING ISSUE DETECTED inside '$vps_name':"
      echo "     Your application is listening ONLY on 127.0.0.1:$target_port (Loopback only)."
      echo "     Host Caddy cannot reach 127.0.0.1 inside the container!"
      echo "     👉 FIX: Configure your application/server inside '$vps_name' to bind to 0.0.0.0:$target_port (or $ip:$target_port) instead of 127.0.0.1."
    else
      echo "  ⚠️  Port $target_port is open inside container ($listening_info), but not reachable from host bridge."
      echo "     Check internal firewall/iptables rules inside '$vps_name'."
    fi
  else
    echo "  ⚠️  NO SERVICE IS LISTENING inside '$vps_name' on port $target_port!"
    echo "     👉 FIX: Start your application/web server inside '$vps_name' on port $target_port."
  fi
  return 1
}
