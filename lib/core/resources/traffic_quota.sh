#!/bin/bash
# VPSForge v1.0.0 — Traffic quota configuration and display.

get_vps_traffic_rx_limit_gb() {
  local val
  val=$(incus config get "$1" user.vpsforge.traffic.rx_limit_gb 2>/dev/null || true)
  [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ] && echo "$val" || echo 0
}

get_vps_traffic_tx_limit_gb() {
  local val
  val=$(incus config get "$1" user.vpsforge.traffic.tx_limit_gb 2>/dev/null || true)
  [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ] && echo "$val" || echo 0
}

set_traffic_mode_for_vps() {
  local name="$1" mode="$2" rx_gb="${3:-0}" tx_gb="${4:-0}"
  case "$mode" in
    unlimited)
      incus config set "$name" user.vpsforge.traffic.rx_limit_gb "0" 2>/dev/null || true
      incus config set "$name" user.vpsforge.traffic.tx_limit_gb "0" 2>/dev/null || true
      reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true
      echo "Traffic data limits set to Unlimited for $name and full network speed restored."
      ;;
    limited)
      [[ "$rx_gb" =~ ^[0-9]+$ ]] || rx_gb=0
      [[ "$tx_gb" =~ ^[0-9]+$ ]] || tx_gb=0
      incus config set "$name" user.vpsforge.traffic.rx_limit_gb "$rx_gb" 2>/dev/null || true
      incus config set "$name" user.vpsforge.traffic.tx_limit_gb "$tx_gb" 2>/dev/null || true
      reset_vps_traffic_limits "$name" >/dev/null 2>&1 || true
      check_vps_traffic_quotas >/dev/null 2>&1 || true
      echo "Traffic data limits updated for $name (Download: ${rx_gb}GB, Upload: ${tx_gb}GB)."
      ;;
    *) return 1;;
  esac
}

TRAFFIC_MODE_RESULT=""
TRAFFIC_RX_RESULT=0
TRAFFIC_TX_RESULT=0

ask_traffic_mode() {
  local target="$1" c rx tx
  while :; do
    echo "----------------------------------------------------------------"
    echo "Traffic Data Limit (Download / Upload Quota) for $target:"
    echo "0) Back"
    echo "1) Unlimited Traffic Data (Default)"
    echo "2) Set Custom Data Quota (Download & Upload in GB)"
    read -r -p "Choice [0=Back, Enter=1]: " c </dev/tty
    c="${c:-1}"
    case "$c" in
      0) return 1;;
      1)
        TRAFFIC_MODE_RESULT="unlimited"
        TRAFFIC_RX_RESULT=0
        TRAFFIC_TX_RESULT=0
        return 0
        ;;
      2)
        read -r -p "Download (Rx) Data Limit in GB [0=Unlimited, Enter=0]: " rx </dev/tty
        rx="${rx:-0}"
        [[ "$rx" =~ ^[0-9]+$ ]] || rx=0

        read -r -p "Upload (Tx) Data Limit in GB [0=Unlimited, Enter=0]: " tx </dev/tty
        tx="${tx:-0}"
        [[ "$tx" =~ ^[0-9]+$ ]] || tx=0

        TRAFFIC_MODE_RESULT="limited"
        TRAFFIC_RX_RESULT="$rx"
        TRAFFIC_TX_RESULT="$tx"
        return 0
        ;;
      *) echo "Invalid choice.";;
    esac
  done
}

get_vps_network_io_display() {
  local name="$1"
  local rx_lim tx_lim t_status
  rx_lim=$(get_vps_traffic_rx_limit_gb "$name" 2>/dev/null || echo 0)
  tx_lim=$(get_vps_traffic_tx_limit_gb "$name" 2>/dev/null || echo 0)
  t_status=$(incus config get "$name" user.vpsforge.traffic.status 2>/dev/null || true)

  incus query "/1.0/instances/$name/state" 2>/dev/null | python3 -c "
import sys, json

rx_lim = $rx_lim
tx_lim = $tx_lim
t_status = '$t_status'

def human_bytes(b):
    if b >= 1073741824: return f'{b/1073741824:.1f}G'
    if b >= 1048576:    return f'{b/1048576:.1f}M'
    if b >= 1024:       return f'{b/1024:.0f}K'
    return f'{b}B'

try:
    data = json.load(sys.stdin)
    eth0 = data.get('network', {}).get('eth0', {})
    counters = eth0.get('counters', {})
    rx = int(counters.get('bytes_received', 0))
    tx = int(counters.get('bytes_sent', 0))

    rx_str = human_bytes(rx)
    if rx_lim > 0:
        rx_str += f'/{rx_lim}G'

    tx_str = human_bytes(tx)
    if tx_lim > 0:
        tx_str += f'/{tx_lim}G'

    out = f'↓{rx_str} ↑{tx_str}'
    if t_status:
        out += f' [⚠️{t_status}]'
    print(out)
except Exception:
    print('-')
" || echo "-"
}
