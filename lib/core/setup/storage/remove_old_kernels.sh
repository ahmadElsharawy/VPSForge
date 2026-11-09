#!/bin/bash
# Purge old kernel packages (they pile up with every update and take over 1GB). The running
# kernel and the newest one are always kept. Skipped while apt/dpkg is busy.
remove_old_kernels() {
  local -a old=()
  command -v dpkg-query >/dev/null 2>&1 || return 0
  if fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; then
    echo "  - old kernels: apt is busy, skipped"
    return 0
  fi
  mapfile -t old < <(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1=="ii"{print $2}' | select_old_kernel_packages "$(uname -r)")
  if [ "${#old[@]}" -eq 0 ]; then
    echo "  - old kernels: none to remove"
    return 0
  fi
  echo "  - removing ${#old[@]} old kernel package(s) (the running one is kept)"
  DEBIAN_FRONTEND=noninteractive apt-get purge -y "${old[@]}" >/dev/null 2>&1 || true
}
