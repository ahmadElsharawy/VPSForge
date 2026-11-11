#!/bin/bash
# Stop services, purge packages, and clean up service directories.
#   _uninstall_stop_and_purge_packages <package_list...>
_uninstall_stop_and_purge_packages() {
  local unit mount
  for unit in caddy incus; do
    printf '%s\n' "$@" | grep -qx "$unit" || continue
    if [ "$unit" = "incus" ]; then
      systemctl disable --now incus incus.socket >/dev/null 2>&1 || true
    else
      systemctl disable --now caddy >/dev/null 2>&1 || true
    fi
  done
  DEBIAN_FRONTEND=noninteractive apt-get purge -y "$@" >/dev/null 2>&1 || true

  if printf '%s\n' "$@" | grep -qx incus; then
    for mount in /var/lib/incus/guestapi /var/lib/incus/shmounts; do umount -l "$mount" 2>/dev/null || true; done
    rm -rf /var/lib/incus /var/log/incus /etc/incus
  fi
  if printf '%s\n' "$@" | grep -qx caddy; then
    rm -f /etc/apt/sources.list.d/caddy-stable.list /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    rm -rf /var/lib/caddy /etc/caddy
  fi
  apt-get update >/dev/null 2>&1 || true
  apt-get clean >/dev/null 2>&1 || true
}
