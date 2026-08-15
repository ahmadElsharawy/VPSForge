#!/bin/bash
# VPSForge v1.0.0 — Firewall persistence.

# ── Firewall Persistence ────────────────────────────────────────────────────

# Persist current iptables rules to disk.
# Tries netfilter-persistent first, falls back to iptables-save.
save_iptables() {
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save >/dev/null 2>&1 || true
  else
    mkdir -p /etc/iptables 2>/dev/null || true
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
  fi
}
