#!/bin/bash
# Install VPSForge's cron jobs: traffic-quota check every 5 minutes, and a
# weekly "reclaim" that gives space freed inside the VPS pool back to the real disk.
install_quota_cron() {
  mkdir -p /etc/cron.d 2>/dev/null || true
  cat <<'EOF' > /etc/cron.d/vpsforge-quota
# VPSForge Traffic Quota Enforcement Daemon (Runs every 5 minutes)
*/5 * * * * root /usr/local/bin/vpsforge quota-check >/dev/null 2>&1
# VPSForge weekly space reclaim (Sunday 04:00): returns freed pool space to the server
0 4 * * 0 root /usr/local/bin/vpsforge reclaim >/dev/null 2>&1
EOF
  chmod 0644 /etc/cron.d/vpsforge-quota 2>/dev/null || true
}
