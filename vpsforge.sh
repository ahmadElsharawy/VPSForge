#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# VPSForge — Interactive Bash manager for lightweight Ubuntu VPS containers
#             powered by Incus.
#
# This file is the entry point. All functionality lives in lib/*.sh modules.
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

VPSFORGE_VERSION="v1.0.7"

# Fast version query (no lib loading needed).
if [[ "${1:-}" == "--version" || "${1:-}" == "-v" || "${1:-}" == "version" ]]; then
  echo "VPSForge $VPSFORGE_VERSION"
  exit 0
fi

# ── Resolve Script Directory (handles symlinks) ─────────────────────────────

VPSFORGE_SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_DIR="$VPSFORGE_SCRIPT_DIR/lib"

# Auto-heal lib/ directory if missing after updating from older versions
if [ ! -d "$LIB_DIR" ]; then
  if [ -d "$VPSFORGE_SCRIPT_DIR/repo/.git" ]; then
    echo "Extracting modular lib/ files..."
    git -C "$VPSFORGE_SCRIPT_DIR/repo" archive HEAD lib 2>/dev/null | tar -x -C "$VPSFORGE_SCRIPT_DIR" 2>/dev/null || true
    chmod +x "$LIB_DIR"/*.sh 2>/dev/null || true
  fi
fi

# ── Load Modules ─────────────────────────────────────────────────────────────

source "$LIB_DIR/core.sh"
source "$LIB_DIR/compat.sh"
source "$LIB_DIR/iptables.sh"
source "$LIB_DIR/network.sh"
source "$LIB_DIR/resources.sh"
source "$LIB_DIR/selection.sh"
source "$LIB_DIR/vps.sh"
source "$LIB_DIR/settings.sh"
source "$LIB_DIR/proxy.sh"
source "$LIB_DIR/menus.sh"

# ── Root Check ───────────────────────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi

# ── Startup ──────────────────────────────────────────────────────────────────

ensure_setup
get_network_info
get_public_ip
setup_inter_vps_isolation
load_settings

# ── CLI Dispatcher ───────────────────────────────────────────────────────────

case "${1:-}" in
  "")
    interactive
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
    echo "Usage: vpsforge [list|details vps1|start vps1|stop vps1|restart vps1|ram vps1 MB|snapshot vps1|backup vps1|repair-all|port-forward]"
    ;;
esac
