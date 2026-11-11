#!/bin/bash
# Perform full host setup: packages, storage, networking, kernel modules, and system links.
ensure_setup_full() {
  capture_pre_install_state

  _ensure_setup_prerequisites
  _ensure_setup_storage
  _ensure_setup_network

  # Host-side kernel modules and sysctls required for Docker/containerd/WireGuard/etc.
  # to work correctly inside nested Incus/LXC system containers.
  ensure_host_kernel_prerequisites
  check_host_compatibility

  # Ensure legacy Docker markers are cleaned up from any pre-existing containers
  cleanup_legacy_dockerenv_markers

  # Nothing downloaded for the install stays on the disk: empty the package cache,
  # and let cached OS images expire after 1 day instead of 10.
  apt-get clean >/dev/null 2>&1 || true
  limit_system_journal
  incus config set images.remote_cache_expiry 1 >/dev/null 2>&1 || true

  _ensure_setup_bin_links

  # Clean any stale backup directories from previous updates
  rm -rf "${VPSFORGE_SCRIPT_DIR:-/opt/vpsforge}/lib.backup" "${VPSFORGE_SCRIPT_DIR:-/opt/vpsforge}/vpsforge.sh.backup" 2>/dev/null || true

  # Ensure autostart configuration is in sync
  apply_autostart_login_config 2>/dev/null || true
}
