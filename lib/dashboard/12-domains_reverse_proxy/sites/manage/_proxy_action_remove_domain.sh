#!/bin/bash
# Remove a domain and all its routes from the VPS Caddy configuration.
#   _proxy_action_remove_domain <vps> <domain> <conf>
_proxy_action_remove_domain() {
  local vps="${1:?vps}" domain="${2:?domain}" conf="${3:?conf}"
  local answer
  read -r -p "Remove $domain and ALL its routes? [y/N]: " answer </dev/tty
  if [[ "${answer,,}" =~ ^y ]]; then
    cp -f "$conf" "${conf}.bak" 2>/dev/null || true
    caddy_unlink_domain "$conf" "$domain"     # only this domain leaves the file
    if [ -f "$conf" ]; then
      if caddy_apply_or_rollback "$conf" "${conf}.bak"; then
        remove_domain_from_guest_hosts "$vps" "$domain" 2>/dev/null || true
        sync_vps_metadata "$vps"
        echo "Removed."
      else
        echo "ERROR: Caddy did not accept the change; nothing was changed."
      fi
    else
      unlink_proxy_domain "$vps" "$domain"   # it was the last domain of this VPS
      echo "Removed."
    fi
    pause
    return 0
  fi
  return 1
}
