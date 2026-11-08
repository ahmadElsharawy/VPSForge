#!/bin/bash
# Wizard step 3 of 5: the domain name.
proxy_wizard_step_domain() {
  local domain last
  last=$(pref_get proxy_domain "")
  echo
  echo "Step 3 of 5 - Your domain name"
  while :; do
    read -r -p "Domain (example: app.mydomain.com)${last:+ [Enter=$last]} [0=Back]: " domain </dev/tty
    [ "$domain" = "0" ] && return "$WIZARD_BACK"
    domain="${domain:-$last}"
    if [[ "$domain" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] && [[ "$domain" == *.* ]]; then
      local other_owner
      if other_owner=$(domain_used_by_other_vps "$domain" "$PW_VPS"); then
        echo "CONFLICT: $domain is already used by VPS $other_owner. Remove it there first, or choose another domain."
        continue
      fi
      PW_DOMAIN="$domain"
      pref_set proxy_domain "$domain"
      return 0
    fi
    echo "That does not look like a domain. Use letters, digits, dots and dashes, like app.mydomain.com"
  done
}
