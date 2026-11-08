#!/bin/bash
get_vps_network_io_display() {
  local name="$1"
  local rx_lim tx_lim t_status
  rx_lim=$(get_vps_traffic_rx_limit_gb "$name" 2>/dev/null || echo 0)
  tx_lim=$(get_vps_traffic_tx_limit_gb "$name" 2>/dev/null || echo 0)
  t_status=$(incus config get "$name" user.vpsforge.traffic.status 2>/dev/null || true)

  incus query "/1.0/instances/$name/state" 2>/dev/null | python3 -c "
import sys, json

rx_lim = int(sys.argv[1])
tx_lim = int(sys.argv[2])
t_status = sys.argv[3]

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
" "$rx_lim" "$tx_lim" "$t_status" || echo "-"
}
