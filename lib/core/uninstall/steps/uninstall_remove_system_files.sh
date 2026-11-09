#!/bin/bash
# Remove cron job, login hook, kernel-module and sysctl files, and the swap file;
# restore the original ip_forward value.
uninstall_remove_system_files() {
  local original_forward=""
  echo "[4/7] Removing system settings VPSForge added..."

  uninstall_run rm -f /etc/cron.d/vpsforge-quota /etc/profile.d/vpsforge-autostart.sh \
    /etc/modules-load.d/vpsforge.conf /etc/sysctl.d/99-vpsforge-nesting.conf /etc/sysctl.d/99-incus-forwarding.conf \
    /etc/systemd/journald.conf.d/vpsforge.conf

  if [ -e "$SWAPFILE_PATH" ]; then
    uninstall_run swapoff "$SWAPFILE_PATH"
    uninstall_run rm -f "$SWAPFILE_PATH"
    [ "${UNINSTALL_DRY_RUN:-0}" = "1" ] || sed -i "\|$SWAPFILE_PATH|d" /etc/fstab 2>/dev/null || true
  fi

  uninstall_restore_ufw

  [ -f "$PRE_INSTALL_DIR/ip_forward" ] && original_forward=$(cat "$PRE_INSTALL_DIR/ip_forward")
  if [[ "$original_forward" =~ ^[01]$ ]]; then
    uninstall_run sysctl -w "net.ipv4.ip_forward=$original_forward"
  fi
}
