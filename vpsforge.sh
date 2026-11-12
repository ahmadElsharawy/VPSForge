#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# VPSForge v1.1.7 — Interactive Bash manager for lightweight Ubuntu VPS
#                   containers powered by Incus.
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

VPSFORGE_VERSION="v3.0.4"

# Fast version query (no lib loading needed).
if [[ "${1:-}" == "--version" || "${1:-}" == "-v" || "${1:-}" == "version" ]]; then
  echo "VPSForge $VPSFORGE_VERSION"
  exit 0
fi

# Ensure root / sudo privileges
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    sudo -E bash "${BASH_SOURCE[0]}" "$@"
    exit $?
  else
    echo "ERROR: VPSForge requires root / sudo privileges." >&2
    exit 1
  fi
fi

# ── Resolve Script Directory (handles symlinks) ─────────────────────────────

VPSFORGE_SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_DIR="$VPSFORGE_SCRIPT_DIR/lib"

# Auto-heal lib/ directory if missing after updating from older versions
if [ ! -d "$LIB_DIR" ]; then
  if [ -d "$VPSFORGE_SCRIPT_DIR/repo/.git" ]; then
    echo "Extracting modular lib/ files..."
    git -C "$VPSFORGE_SCRIPT_DIR/repo" archive HEAD lib 2>/dev/null | tar -x -C "$VPSFORGE_SCRIPT_DIR" 2>/dev/null || true
    find "$LIB_DIR" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
  fi
fi

# Load every library file (one function per file, any folder depth).
if [ -f "$LIB_DIR/load_vpsforge_lib.sh" ]; then
  source "$LIB_DIR/load_vpsforge_lib.sh"
  load_vpsforge_lib "$LIB_DIR"
fi

# ── Startup ──────────────────────────────────────────────────────────────────

sync_active_from_repo 2>/dev/null || true
if [ "${1:-}" = "setup" ]; then
  ensure_setup force
  echo "Setup completed."
  exit 0
fi
if [ "${1:-}" = "uninstall" ]; then
  shift
  get_network_info 2>/dev/null || true
  vpsforge_uninstall "$@"
  exit $?
fi
# Light commands: no full startup (the cron jobs run these every few minutes).
case "${1:-}" in
  quota-check) check_vps_traffic_quotas; vpn_check_limits; tunnel_pending_cleanup; exit 0;;
  tidy) get_network_info 2>/dev/null || true; host_tidy; exit 0;;
  reclaim) reclaim_pool_space; echo "Freed disk space returned to the server."; exit 0;;
  update|upgrade)
    shift
    get_network_info 2>/dev/null || true
    vpsforge_with_update_lock vpsforge_perform_update "$@"
    exit $?
    ;;
esac
ensure_setup
ensure_incus_alive || exit 1
get_network_info || exit 1
recover_interrupted_operations
get_public_ip
setup_inter_vps_isolation
port_forward_load_rules_from_file "$PORT_FORWARD_RULES_FILE" >/dev/null 2>&1 || true
load_settings
install_quota_cron 2>/dev/null || true

# ── CLI Dispatcher ───────────────────────────────────────────────────────────

case "${1:-}" in
  "")
    interactive
    ;;
  update|upgrade)
    shift
    vpsforge_with_update_lock vpsforge_perform_update "$@"
    ;;
  quota-check)
    check_vps_traffic_quotas
    vpn_check_limits
    tunnel_pending_cleanup
    ;;
  list)
    list_vps
    ;;
  details)
    if incus info "${2:-}" >/dev/null 2>&1; then
      details "$2"
    else
      echo "Usage: vpsforge details vps1"
      exit 1
    fi
    ;;
  start|stop|restart)
    incus "$1" "${2:-}"
    ;;
  ram)
    if [ -n "${2:-}" ] && [ -n "${3:-}" ]; then
      set_ram_mode_for_vps "$2" limited "$3" && echo "RAM of $2 set to ${3} MB."
    else
      echo "Usage: vpsforge ram vps1 1024"
    fi
    ;;
  repair|repair-all)
    repair_connection_menu
    ;;
  port-forward|portforward)
    shift
    port_forward_cli "$@"
    ;;
  snapshot)
    if [ -n "${2:-}" ]; then
      create_vps_snapshot "$2" "${3:-}"
    else
      echo "Usage: vpsforge snapshot vps1 [snapshot_name]"
    fi
    ;;
  clone)
    if [ -n "${2:-}" ]; then
      clone_vps "$2" "${3:-${2}-clone}"
    else
      echo "Usage: vpsforge clone <vps> [new_name]"
    fi
    ;;
  selftest)
    incus_compat_check
    ;;
  incus)
    shift
    incus_cli "$@"
    ;;
  clean-backups)
    clean_orphaned_backups
    ;;
  tidy)
    host_tidy
    ;;
  reclaim)
    reclaim_pool_space
    echo "Freed disk space returned to the server."
    ;;
  backup)
    if [ -n "${2:-}" ]; then
      export_vps_backup "$2"
    else
      echo "Usage: vpsforge backup vps1"
    fi
    ;;
  *)
    echo "Usage: vpsforge [list|details vps1|start vps1|stop vps1|restart vps1|ram vps1 MB|snapshot vps1|backup vps1|repair-all|port-forward|update|clean-backups|reclaim|tidy|clone|selftest|incus|setup|uninstall]"
    ;;
esac
