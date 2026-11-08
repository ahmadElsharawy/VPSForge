#!/bin/bash
port_forward_status() {
  echo "=== Active NAT PREROUTING Rules ==="
  iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null || true
  echo
  echo "=== Active FORWARD Rules ==="
  iptables -L FORWARD -n --line-numbers 2>/dev/null | head -n 60 || true
  echo
  local file="${PORT_FORWARD_RULES_FILE}"
  if [ -f "$file" ]; then
    echo "=== Saved Port Forward File ($file) ==="
    cat "$file"
  else
    echo "=== No saved port forward file ==="
  fi
}
