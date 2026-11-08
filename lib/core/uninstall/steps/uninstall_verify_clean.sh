#!/bin/bash
# After uninstall: list anything of VPSForge that is still on the server.
uninstall_verify_clean() {
  local leftovers=0 path
  echo
  echo "Verifying the server is clean..."
  for path in /opt/vpsforge /usr/local/bin/vpsforge /etc/caddy/vpsforge /etc/cron.d/vpsforge-quota \
              /etc/profile.d/vpsforge-autostart.sh /etc/modules-load.d/vpsforge.conf \
              /etc/sysctl.d/99-vpsforge-nesting.conf "$SWAPFILE_PATH" /var/lib/incus /etc/incus; do
    if [ -e "$path" ]; then
      echo "  still present: $path"
      leftovers=$((leftovers + 1))
    fi
  done
  if iptables-save 2>/dev/null | grep -q 'incusbr0'; then
    echo "  still present: iptables rules mentioning incusbr0"
    leftovers=$((leftovers + 1))
  fi
  if [ "$leftovers" -eq 0 ]; then
    echo "  CLEAN: nothing of VPSForge is left on this server."
    return 0
  fi
  echo "  $leftovers item(s) left (see above)."
  return 1
}
