#!/bin/bash
# VPSForge v1.0.0 — Initial setup and dependency installation.

ensure_setup() {
  command -v incus >/dev/null 2>&1 || { apt-get update && apt-get install -y incus; }
  command -v iptables >/dev/null 2>&1 || apt-get install -y iptables
  command -v netfilter-persistent >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
  command -v curl >/dev/null 2>&1 || apt-get install -y curl
  command -v python3 >/dev/null 2>&1 || apt-get install -y python3
  command -v zstd >/dev/null 2>&1 || apt-get install -y zstd
  command -v pigz >/dev/null 2>&1 || apt-get install -y pigz
  command -v fuser >/dev/null 2>&1 || apt-get install -y psmisc
  command -v mkfs.btrfs >/dev/null 2>&1 || apt-get install -y btrfs-progs
  
  incus network show incusbr0 >/dev/null 2>&1 || incus admin init --minimal

  # Optimize storage: recreate default dir pool as BTRFS for instant snapshots
  if incus storage show default >/dev/null 2>&1; then
    if incus storage show default | grep -q 'driver: dir'; then
      local used_by
      used_by=$(incus storage show default | grep -A 10 'used_by:' | grep -v 'used_by:' | grep -c '-' || true)
      if [ "$used_by" -eq 0 ]; then
        incus storage delete default >/dev/null 2>&1 || true
        incus storage create default btrfs size=25GiB >/dev/null 2>&1 || true
      else
        # Automatically migrate existing containers to BTRFS safely!
        if incus storage create temp-btrfs btrfs size=25GiB >/dev/null 2>&1 || incus storage show temp-btrfs >/dev/null 2>&1; then
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
            # Save running state
            local istate
            istate=$(incus info "$inst" 2>/dev/null | awk '/^Status:/ {print $2}' || echo "STOPPED")
            if [ "$istate" = "RUNNING" ]; then
              state_map+=("$inst")
              incus stop "$inst" --force >/dev/null 2>&1 || true
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
          incus storage create default btrfs size=25GiB >/dev/null 2>&1 || true

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
    incus storage create default btrfs size=25GiB >/dev/null 2>&1 || true
  fi

  # Ensure default profile has root device pointing to default storage pool
  incus profile device add default root disk path=/ pool=default >/dev/null 2>&1 || true

  incus config set backups.compression_algorithm none >/dev/null 2>&1 || true

  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-incus-forwarding.conf

  setup_inter_vps_isolation

  # Host-side kernel modules and sysctls required for Docker/containerd/WireGuard/etc.
  # to work correctly inside nested Incus/LXC system containers.
  ensure_host_kernel_prerequisites
  check_host_compatibility

  # Ensure legacy Docker markers are cleaned up from any pre-existing containers
  cleanup_legacy_dockerenv_markers

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

cleanup_legacy_dockerenv_markers() {
  local inst_list inst
  inst_list=$(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)
  [ -n "$inst_list" ] || return 0

  for inst in $inst_list; do
    # Remove /.dockerenv via incus file delete (supported for both running and stopped instances)
    incus file delete "$inst/.dockerenv" >/dev/null 2>&1 || true
    # Also verify via exec if container is running
    local istate
    istate=$(incus info "$inst" 2>/dev/null | awk '/^Status:/ {print $2}' || echo "STOPPED")
    if [ "$istate" = "RUNNING" ]; then
      incus exec "$inst" -- sh -c 'test -e /.dockerenv && rm -f /.dockerenv' 2>/dev/null || true
    fi
  done
}

clean_stale_temp_backups() {
  local tmp_dir="/opt/vpsforge-backups/.tmp"
  if [ -d "$tmp_dir" ]; then
    local f
    for f in "$tmp_dir"/*; do
      [ -f "$f" ] || continue
      if ! fuser "$f" >/dev/null 2>&1; then
        rm -f "$f"
      fi
    done
  fi

  # Clean internal Incus orphaned backups
  local inst_list inst backup_list b_name
  inst_list=$(incus list -c n --format csv 2>/dev/null | grep -v '^$' || true)
  for inst in $inst_list; do
    backup_list=$(incus query "/1.0/instances/${inst}/backups" 2>/dev/null | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, dict):
        data = data.get("metadata", [])
    if isinstance(data, list):
        for path in data:
            print(path.split("/").pop())
except Exception:
    pass
' 2>/dev/null || true)
    for b_name in $backup_list; do
      [ -n "$b_name" ] || continue
      incus query -X DELETE "/1.0/instances/${inst}/backups/${b_name}" >/dev/null 2>&1 || true
    done
  done
}
