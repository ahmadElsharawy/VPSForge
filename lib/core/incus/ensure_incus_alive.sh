#!/bin/bash
# Quick health check run at every start: Incus must answer. If it does not,
# restart it; if it is missing or still broken, reinstall it from the internet.
ensure_incus_alive() {
  incus info >/dev/null 2>&1 && return 0

  echo "Incus is not answering. Trying to repair it..."
  systemctl restart incus.socket incus.service >/dev/null 2>&1 || true
  incus admin waitready --timeout=30 >/dev/null 2>&1 || true
  incus info >/dev/null 2>&1 && { echo "Incus restarted and is fine again."; return 0; }

  incus_reinstall_online
}
