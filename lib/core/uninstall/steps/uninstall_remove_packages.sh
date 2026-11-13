#!/bin/bash
# Purge exactly the packages VPSForge installed, including dependencies.
uninstall_remove_packages() {
  # pre-install capture records which of VPSForge's own packages were ALREADY on the
  # server (packages_present.txt). We remove the rest of VPSForge's packages - the ones
  # it installed - and keep everything that predates it.
  local present="$PRE_INSTALL_DIR/packages_present.txt"
  local pkg
  local -a to_remove=()
  echo "[6/7] Removing packages installed by VPSForge..."
  apt-mark unhold incus incus-base incus-client >/dev/null 2>&1 || true   # the update hold was ours

  if [ ! -d "$PRE_INSTALL_DIR" ] || [ ! -f "$PRE_INSTALL_DIR/packages_all.txt" ]; then
    echo "  (no pre-install record: this server was set up by an older VPSForge, none removed)"
    return 0
  fi
  if [ "${UNINSTALL_FOREIGN_INSTANCES:-0}" -gt 0 ]; then
    echo "  (other containers exist: packages kept)"
    return 0
  fi

  for pkg in $VPSFORGE_PACKAGES; do
    [ -n "$pkg" ] || continue
    dpkg -s "$pkg" >/dev/null 2>&1 || continue
    # keep any of our packages that were already on the server before VPSForge
    [ -f "$present" ] && grep -qxF "$pkg" "$present" && continue
    to_remove+=("$pkg")
  done
  [ "${#to_remove[@]}" -gt 0 ] || { echo "  (nothing to remove: every package VPSForge needs was already here)"; return 0; }

  _uninstall_check_package_dependencies "${to_remove[@]}" || return 0

  if [ "${UNINSTALL_DRY_RUN:-0}" = "1" ]; then
    echo "  - apt-get purge -y (${#to_remove[@]} packages: ${to_remove[*]:0:8}...)"
    return 0
  fi

  _uninstall_stop_and_purge_packages "${to_remove[@]}"
  return 0
}
