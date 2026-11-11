#!/bin/bash
# Purge exactly the packages VPSForge installed, including dependencies.
uninstall_remove_packages() {
  local record="$PRE_INSTALL_DIR/packages_installed.txt" baseline="$PRE_INSTALL_DIR/packages_all.txt"
  local pkg
  local -a to_remove=()
  echo "[6/7] Removing packages installed by VPSForge..."
  apt-mark unhold incus incus-base incus-client >/dev/null 2>&1 || true   # the update hold was ours

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

  _uninstall_check_package_dependencies "${to_remove[@]}" || return 0

  if [ "${UNINSTALL_DRY_RUN:-0}" = "1" ]; then
    echo "  - apt-get purge -y (${#to_remove[@]} packages: ${to_remove[*]:0:8}...)"
    return 0
  fi

  _uninstall_stop_and_purge_packages "${to_remove[@]}"
  return 0
}
