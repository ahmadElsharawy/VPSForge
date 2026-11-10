#!/bin/bash
ensure_setup_full() {
  capture_pre_install_state

  # Check the package (not just the "incus" command: the client alone has no daemon).
  dpkg -s incus >/dev/null 2>&1 || { apt-get update && vpsforge_apt_install incus; }
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
  command -v mkfs.btrfs >/dev/null 2>&1 || vpsforge_apt_install btrfs-progs
  
  incus network show incusbr0 >/dev/null 2>&1 || incus admin init --minimal

  # Optimize storage: recreate default dir pool as BTRFS for instant snapshots
  if [ -f /opt/vpsforge/.pool_migration_running ]; then
    migrate_default_pool_to_btrfs   # a migration was stopped half-way: finish it first
  elif incus storage show default >/dev/null 2>&1; then
    if incus storage show default | grep -q 'driver: dir'; then
      local used_by
      used_by=$(incus storage show default | grep -A 10 'used_by:' | grep -v 'used_by:' | grep -c '-' || true)
      if [ "$used_by" -eq 0 ]; then
        incus storage delete default >/dev/null 2>&1 || true
        create_storage_pool default || true
      else
        migrate_default_pool_to_btrfs
      fi
    fi
  else
    create_storage_pool default || true
  fi

  # Ensure default profile has root device pointing to default storage pool
  incus profile device add default root disk path=/ pool=default >/dev/null 2>&1 || true

  incus config set backups.compression_algorithm none >/dev/null 2>&1 || true

  ensure_host_swap 2>/dev/null || true

  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-incus-forwarding.conf

  setup_inter_vps_isolation

  # Ensure host firewall permits incoming HTTP (80) and HTTPS (443) for Caddy Reverse Proxy
  iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || true
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 80/tcp >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
  fi
  save_iptables 2>/dev/null || true

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

  # Ensure vpsforge symlink in PATH
  local app_script="${VPSFORGE_SCRIPT_DIR:-/opt/vpsforge}/vpsforge.sh"
  if [ -f "$app_script" ]; then
    mkdir -p /usr/local/bin
    ln -sf "$app_script" /usr/local/bin/vpsforge 2>/dev/null || true
    ln -sf "$app_script" /usr/local/bin/VPSForge 2>/dev/null || true
    ln -sf "$app_script" /usr/local/bin/VPSFORGE 2>/dev/null || true
    chmod 755 "$app_script" 2>/dev/null || true

    cat > /usr/local/bin/vpsforge-update <<'UPD_WRAPPER'
#!/bin/bash
set -euo pipefail
APP="/opt/vpsforge/vpsforge.sh"
if [ ! -x "$APP" ]; then
  APP="$(command -v vpsforge 2>/dev/null || echo "")"
fi
[ -n "$APP" ] && [ -x "$APP" ] || { echo "ERROR: VPSForge executable not found."; exit 1; }
exec "$APP" update "$@"
UPD_WRAPPER
    chmod 755 /usr/local/bin/vpsforge-update 2>/dev/null || true
  fi

  # Clean any stale backup directories from previous updates
  rm -rf "${VPSFORGE_SCRIPT_DIR:-/opt/vpsforge}/lib.backup" "${VPSFORGE_SCRIPT_DIR:-/opt/vpsforge}/vpsforge.sh.backup" 2>/dev/null || true

  # Ensure autostart configuration is in sync
  apply_autostart_login_config 2>/dev/null || true
}
