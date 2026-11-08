#!/bin/bash
# Remove the "127.0.0.1 <domain>" line that linking a domain added to the VPS's /etc/hosts.
#   remove_domain_from_guest_hosts <vps_name> <domain>
remove_domain_from_guest_hosts() {
  local name="${1:?name}" domain="${2:?domain}"
  is_vps_running "$name" || return 0
  incus exec "$name" --env DOMAIN="$domain" -- sh -c 'sed -i "/^127\.0\.0\.1 $DOMAIN\$/d" /etc/hosts' >/dev/null 2>&1 || true
}
