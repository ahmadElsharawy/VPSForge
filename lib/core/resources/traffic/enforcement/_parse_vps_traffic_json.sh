#!/bin/bash
# Parses Incus JSON from stdin into pipe-delimited records for traffic quota enforcement.
_parse_vps_traffic_json() {
  python3 -c '
import sys, json

def num(value):
    try:
        return max(0, int(float(value or 0)))
    except (TypeError, ValueError):
        return 0

try:
    instances = json.load(sys.stdin)
except Exception:
    instances = []
for inst in instances:
    cfg = inst.get("config") or {}
    # Sum every interface except loopback, not just "eth0". A tenant with root could rename eth0 (e.g.
    # `ip link set eth0 name wan0`) to make the eth0 counters vanish and freeze its usage total, getting
    # unmetered traffic. Summing all non-loopback interfaces still counts the real traffic after a rename.
    net = ((inst.get("state") or {}).get("network") or {})
    rx_bytes = 0
    tx_bytes = 0
    for _ifname, _idata in net.items():
        if _ifname == "lo":
            continue
        _c = (_idata or {}).get("counters") or {}
        rx_bytes += num(_c.get("bytes_received"))
        tx_bytes += num(_c.get("bytes_sent"))
    fields = [
        inst.get("name", ""),
        num(cfg.get("user.vpsforge.traffic.rx_limit_gb")),
        num(cfg.get("user.vpsforge.traffic.tx_limit_gb")),
        (cfg.get("user.vpsforge.traffic.status") or "").replace("|", " "),
        (cfg.get("user.vpsforge.traffic.action") or "").replace("|", " "),
        num(cfg.get("user.vpsforge.traffic.used_rx")),
        num(cfg.get("user.vpsforge.traffic.used_tx")),
        num(cfg.get("user.vpsforge.traffic.last_rx")),
        num(cfg.get("user.vpsforge.traffic.last_tx")),
        (cfg.get("user.vpsforge.traffic.period") or ""),
        rx_bytes,
        tx_bytes,
        1 if inst.get("status") == "Running" else 0,
    ]
    print("|".join(str(f) for f in fields))
' 2>/dev/null || true
}
