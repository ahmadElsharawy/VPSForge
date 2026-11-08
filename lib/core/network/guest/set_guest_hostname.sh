#!/bin/bash
set_guest_hostname() {
  local name="${1:-}" old_name="${2:-}"
  [ -n "$name" ] || return 0

  incus exec "$name" -- sh -c "
    new_h='$name'
    old_h='$old_name'

    # 1. Update /etc/hostname
    echo \"\$new_h\" > /etc/hostname 2>/dev/null || true

    # 2. Update /etc/hosts
    if [ -f /etc/hosts ]; then
      if [ -n \"\$old_h\" ]; then
        sed -i -E \"s/\b\${old_h}\b/\${new_h}/g\" /etc/hosts 2>/dev/null || true
      fi
      if ! grep -qw \"\$new_h\" /etc/hosts 2>/dev/null; then
        echo \"127.0.1.1 \$new_h\" >> /etc/hosts 2>/dev/null || true
      fi
    fi

    # 3. Update runtime hostname
    if command -v hostnamectl >/dev/null 2>&1; then
      hostnamectl set-hostname \"\$new_h\" 2>/dev/null || true
    fi
    if command -v hostname >/dev/null 2>&1; then
      hostname \"\$new_h\" 2>/dev/null || true
    fi

    # 4. Prevent cloud-init from resetting hostname
    if [ -f /etc/cloud/cloud.cfg ]; then
      if grep -q '^preserve_hostname:' /etc/cloud/cloud.cfg 2>/dev/null; then
        sed -i 's/^preserve_hostname:.*/preserve_hostname: true/' /etc/cloud/cloud.cfg 2>/dev/null || true
      else
        echo 'preserve_hostname: true' >> /etc/cloud/cloud.cfg 2>/dev/null || true
      fi
    fi
  " >/dev/null 2>&1 || true
}
