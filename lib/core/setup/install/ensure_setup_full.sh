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
  if incus storage show default >/dev/null 2>&1; then
    if incus storage show default | grep -q 'driver: dir'; then
      local used_by
      used_by=$(incus storage show default | grep -A 10 'used_by:' | grep -v 'used_by:' | grep -c '-' || true)
      if [ "$used_by" -eq 0 ]; then
        incus storage delete default >/dev/null 2>&1 || true
        create_storage_pool default || true
      else
        # Automatically migrate existing containers to BTRFS safely!
        if incus storage create temp-btrfs btrfs size=$(default_pool_size_gib)GiB >/dev/null 2>&1 || incus storage show temp-btrfs >/dev/null 2>&1; then
          echo "Storage pool 'default' is using 'dir' driver. Automating migration to BTRFS..." >&2
          local -a instances=()
          mapfile -t instances < <(incus storage show default 2>/dev/null | grep '/1.0/instances/' | awk -F'/' '{print $NF}' || true)
          
          local -a profiles=()
          mapfile -t profiles < <(incus storage show default 2>/dev/null | grep '/1.0/profiles/' | awk -F'/' '{print $NF}' || true)

          # 1. Stop and move instances to temp pool
          local inst
          local -a state_map=()
          for inst in "${instances[@]}"; do
            [ -n "$inst" ] || continue
            if is_vps_running "$inst"; then
              state_map+=("$inst")
              incus stop "$inst" --force >/dev/null 2>&1 || true
              local wait_count=0
              while is_vps_running "$inst" && [ $wait_count -lt 15 ]; do
                sleep 1
                wait_count=$((wait_count + 1))
              done
            fi
            incus move "$inst" "$inst" -s temp-btrfs >/dev/null 2>&1 || true
          done

          # 2. Temporarily remove root device from profiles
          local prof
          for prof in "${profiles[@]}"; do
            [ -n "$prof" ] || continue
            incus profile device remove "$prof" root >/dev/null 2>&1 || true
          done

          # 3. Delete old dir default pool and recreate as BTRFS
          incus storage delete default >/dev/null 2>&1 || true
          create_storage_pool default || true

          # 4. Restore root device to profiles pointing to new default pool
          for prof in "${profiles[@]}"; do
            [ -n "$prof" ] || continue
            incus profile device add "$prof" root disk path=/ pool=default >/dev/null 2>&1 || true
          done

          # 5. Move instances back to default BTRFS pool
          for inst in "${instances[@]}"; do
            [ -n "$inst" ] || continue
            incus move "$inst" "$inst" -s default >/dev/null 2>&1 || true
          done

          # 6. Delete temp BTRFS pool
          incus storage delete temp-btrfs >/dev/null 2>&1 || true

          # 7. Start instances that were previously running
          local run_inst
          for run_inst in "${state_map[@]}"; do
            incus start "$run_inst" >/dev/null 2>&1 || true
          done

          echo "BTRFS storage optimization completed successfully." >&2
        else
          echo "WARNING: Could not create temporary BTRFS storage pool. Skipping BTRFS storage migration." >&2
        fi
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
