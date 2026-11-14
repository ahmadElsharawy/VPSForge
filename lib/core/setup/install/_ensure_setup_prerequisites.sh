#!/bin/bash
# Install core packages and initialize Incus network if not already present.
_ensure_setup_prerequisites() {
  # Check the package (not just the "incus" command: the client alone has no daemon).
  dpkg -s incus >/dev/null 2>&1 || { wait_for_apt_lock; apt-get update && vpsforge_apt_install incus; }
  ensure_incus_usable
  systemctl enable --now incus.socket incus.service >/dev/null 2>&1 || true
  incus admin waitready --timeout=60 >/dev/null 2>&1 || true
  check_incus_version
  pin_incus_if_tested
  command -v iptables >/dev/null 2>&1 || vpsforge_apt_install iptables
  command -v netfilter-persistent >/dev/null 2>&1 || vpsforge_apt_install iptables-persistent
  command -v curl >/dev/null 2>&1 || vpsforge_apt_install curl
  command -v python3 >/dev/null 2>&1 || vpsforge_apt_install python3
  command -v zstd >/dev/null 2>&1 || vpsforge_apt_install zstd
  command -v pigz >/dev/null 2>&1 || vpsforge_apt_install pigz
  command -v fuser >/dev/null 2>&1 || vpsforge_apt_install psmisc
  command -v zpool >/dev/null 2>&1 || vpsforge_apt_install zfsutils-linux || true   # no ZFS: the pool falls back to btrfs
  command -v mkfs.btrfs >/dev/null 2>&1 || vpsforge_apt_install btrfs-progs

  incus network show incusbr0 >/dev/null 2>&1 || incus admin init --minimal
}
