#!/bin/bash
# After uninstall: list anything of VPSForge that is still on the server.
uninstall_verify_clean() {
  local leftovers=0 path incus_paths="/var/lib/incus /etc/incus"
  # Incus that was kept on purpose (it was here before VPSForge, or other containers use it) is not a leftover.
  [ "${UNINSTALL_KEPT_INCUS:-0}" = "1" ] && incus_paths=""
  echo
  echo "Verifying the server is clean..."
  for path in /opt/vpsforge /usr/local/bin/vpsforge /etc/caddy/vpsforge /etc/cron.d/vpsforge-quota \
              /etc/profile.d/vpsforge-autostart.sh /etc/modules-load.d/vpsforge.conf \
              /etc/sysctl.d/99-vpsforge-nesting.conf "$SWAPFILE_PATH" $incus_paths; do
    if [ -e "$path" ]; then
      echo "  still present: $path"
      leftovers=$((leftovers + 1))
    fi
  done
  if [ "${UNINSTALL_KEPT_INCUS:-0}" != "1" ] && iptables-save 2>/dev/null | grep -q 'incusbr0'; then
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
