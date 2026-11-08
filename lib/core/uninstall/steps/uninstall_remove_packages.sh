#!/bin/bash
# Purge exactly the packages VPSForge installed (the list written by
# vpsforge_apt_install and install.sh), including the dependencies they pulled in.
# Anything that existed before VPSForge is never touched, and if removing them
# would also remove a package the owner installed later, nothing is removed.
uninstall_remove_packages() {
  local record="$PRE_INSTALL_DIR/packages_installed.txt" baseline="$PRE_INSTALL_DIR/packages_all.txt"
  local pkg removed mount
  local -a to_remove=() extras=()
  echo "[6/7] Removing packages installed by VPSForge..."

  if [ ! -s "$record" ]; then
    echo "  (no record of installed packages: this server was set up by an older VPSForge, none removed)"
    return 0
  fi
  if [ "${UNINSTALL_FOREIGN_INSTANCES:-0}" -gt 0 ]; then
    echo "  (other containers exist: packages kept)"
    return 0
  fi

  while read -r pkg; do
    [ -n "$pkg" ] || continue
    dpkg -s "$pkg" >/dev/null 2>&1 || continue
    # never touch what was on the server before VPSForge
    [ -f "$baseline" ] && grep -qxF "$pkg" "$baseline" && continue
    to_remove+=("$pkg")
  done < "$record"
  [ "${#to_remove[@]}" -gt 0 ] || { echo "  (nothing to remove)"; return 0; }

  # Dry simulation: would apt remove anything that is NOT in our list?
  while read -r removed; do
    [ -n "$removed" ] || continue
    printf '%s\n' "${to_remove[@]}" | grep -qxF "$removed" || extras+=("$removed")
  done < <(apt-get -s purge "${to_remove[@]}" 2>/dev/null | awk '/^Remv /{print $2}')
  if [ "${#extras[@]}" -gt 0 ]; then
    echo "  Not removed: other packages you installed later depend on them (${extras[*]})."
    return 0
  fi

  if [ "${UNINSTALL_DRY_RUN:-0}" = "1" ]; then
    echo "  - apt-get purge -y (${#to_remove[@]} packages: ${to_remove[*]:0:8}...)"
    return 0
  fi

  systemctl disable --now caddy incus incus.socket >/dev/null 2>&1 || true
  DEBIAN_FRONTEND=noninteractive apt-get purge -y "${to_remove[@]}" >/dev/null 2>&1 || true

  if printf '%s\n' "${to_remove[@]}" | grep -qx incus; then
    for mount in /var/lib/incus/guestapi /var/lib/incus/shmounts; do umount -l "$mount" 2>/dev/null || true; done
    rm -rf /var/lib/incus /var/log/incus /etc/incus
  fi
  if printf '%s\n' "${to_remove[@]}" | grep -qx caddy; then
    rm -f /etc/apt/sources.list.d/caddy-stable.list /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    rm -rf /var/lib/caddy /etc/caddy
  fi
  apt-get update >/dev/null 2>&1 || true
  apt-get clean >/dev/null 2>&1 || true
  return 0
}
