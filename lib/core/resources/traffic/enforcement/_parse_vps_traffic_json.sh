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
    eth0 = ((inst.get("state") or {}).get("network") or {}).get("eth0") or {}
    counters = eth0.get("counters") or {}
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
        num(counters.get("bytes_received")),
        num(counters.get("bytes_sent")),
        1 if inst.get("status") == "Running" else 0,
    ]
    print("|".join(str(f) for f in fields))
' 2>/dev/null || true
}
