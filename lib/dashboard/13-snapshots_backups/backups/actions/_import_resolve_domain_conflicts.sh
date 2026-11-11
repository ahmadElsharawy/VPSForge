#!/bin/bash
# Scan Caddy reverse proxy domains from backup archive and resolve domain conflicts.
_import_resolve_domain_conflicts() {
  [ -n "$proxy_b64" ] && [ "$proxy_b64" != "-" ] || return 0

  echo
  echo "Scanning Reverse Proxy (Caddy) domains for conflicts..."
  proxy_decoded=$(echo "$proxy_b64" | base64 -d 2>/dev/null || true)
  local domains_str domain_arr dom conflicting_vps conflict_file choice
  domains_str=$(caddy_site_domains <<< "$proxy_decoded" | sort -u | tr '\n' ' ')
  [ -n "$domains_str" ] || return 0

  IFS=' ' read -ra domain_arr <<< "$domains_str"
  for dom in "${domain_arr[@]}"; do
    dom=${dom%,}
    [ -n "$dom" ] || continue

    conflicting_vps=$(domain_used_by_other_vps "$dom" "$target_name" || true)
    conflict_file=""
    [ -n "$conflicting_vps" ] && conflict_file="$CADDY_CONF_DIR/${conflicting_vps}.caddy"
    if [ -n "$conflict_file" ]; then
      echo
      echo "⚠️  DOMAIN CONFLICT detected for Domain [ $dom ]"
      echo "   Domain '$dom' is already linked to VPS '$conflicting_vps'."
      echo "   1) Skip this domain (Default)"
      echo "   2) Takeover (unlink from '$conflicting_vps' and link to '$target_name')"
      read -r -p "   Choice [1-2, Enter=1]: " choice </dev/tty
      choice="${choice:-1}"
      if [ "$choice" = "2" ]; then
        echo "   Will take over domain '$dom' (unlinking from '$conflicting_vps')..."
        caddy_conflicts_to_remove+=("$conflict_file|$dom")
        domains_to_apply+=("$dom")
      else
        echo "   Skipped domain '$dom'."
        domains_skipped+=("$dom")
      fi
    else
      domains_to_apply+=("$dom")
    fi
  done
}
