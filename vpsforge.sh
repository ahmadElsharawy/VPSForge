#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# VPSForge v1.0.5 — Interactive Bash manager for lightweight Ubuntu VPS
#                   containers powered by Incus.
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

VPSFORGE_VERSION="v1.0.5"

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

# Sourcing all module files dynamically
if [ -d "$LIB_DIR" ]; then
  # 1. Load direct files in core first (constants, helpers, etc.)
  for core_file in "$LIB_DIR"/core/*.sh; do
    [ -f "$core_file" ] && source "$core_file"
  done

  # 2. Load all nested core modules recursively
  while read -r lib_file; do
    source "$lib_file"
  done < <(find "$LIB_DIR/core" -mindepth 2 -type f -name "*.sh" | sort)

  # 3. Load all other sub-module files dynamically (like dashboard)
  while read -r lib_file; do
    source "$lib_file"
  done < <(find "$LIB_DIR" -type f -name "*.sh" ! -path "*/core/*" | sort)
fi

# ── Root Check ───────────────────────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi

# ── Startup ──────────────────────────────────────────────────────────────────

sync_active_from_repo 2>/dev/null || true
ensure_setup
get_network_info
get_public_ip
setup_inter_vps_isolation
load_settings
install_quota_cron 2>/dev/null || true

# ── CLI Dispatcher ───────────────────────────────────────────────────────────

case "${1:-}" in
  "")
    interactive
    ;;
  update|upgrade)
    shift
    vpsforge_perform_update "$@"
    ;;
  quota-check)
    check_vps_traffic_quotas
    ;;
  list)
    list_vps
    ;;
  details)
    incus info "${2:-}" >/dev/null 2>&1 && details "$2" || { echo "Usage: vpsforge details vps1"; exit 1; }
    ;;
  start|stop|restart)
    incus "$1" "${2:-}"
    ;;
  ram)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] && incus config set "$2" limits.memory "${3}MiB" || \
      echo "Usage: vpsforge ram vps1 1024"
    ;;
  repair|repair-all)
    repair_connection_menu
    ;;
  port-forward|portforward)
    shift
    port_forward_cli "$@"
    ;;
  snapshot)
    [ -n "${2:-}" ] && create_vps_snapshot "$2" "${3:-}" || echo "Usage: vpsforge snapshot vps1 [snapshot_name]"
    ;;
  backup)
    [ -n "${2:-}" ] && export_vps_backup "$2" || echo "Usage: vpsforge backup vps1"
    ;;
  *)
    echo "Usage: vpsforge [list|details vps1|start vps1|stop vps1|restart vps1|ram vps1 MB|snapshot vps1|backup vps1|repair-all|port-forward|update]"
    ;;
esac
