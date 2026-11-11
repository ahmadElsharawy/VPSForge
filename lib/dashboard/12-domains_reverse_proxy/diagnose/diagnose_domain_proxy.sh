#!/bin/bash
# Run health checks for a domain reverse proxy route (Caddy, backend, DNS, SSL).
#   diagnose_domain_proxy <vps_name> <domain> [target_schema] <ip> <target_port> [url_path]
diagnose_domain_proxy() {
  local vps_name="$1" domain="$2" target_schema="${3:-http}" ip="$4" target_port="$5" url_path="${6:-}"

  echo
  echo "================================================================"
  echo "         REVERSE PROXY & DOMAIN HEALTH VERIFICATION"
  echo "================================================================"
  echo "Domain:          $domain"
  echo "Target VPS:      $vps_name"
  echo "Backend Target:  ${target_schema}://$ip:$target_port"
  [ -n "$url_path" ] && echo "Routed Path:     $url_path"
  echo "----------------------------------------------------------------"

  local all_ok=1

  _diagnose_caddy_service || all_ok=0
  _diagnose_backend_connectivity "$vps_name" "$target_schema" "$ip" "$target_port" || all_ok=0
  _diagnose_dns_resolution "$domain" || all_ok=0
  _diagnose_acme_ssl "$domain" || all_ok=0

  echo "================================================================"
  if [ "$all_ok" -eq 1 ]; then
    echo "✅ REVERSE PROXY VERIFIED & OPERATIONAL:"
    echo "   https://$domain$url_path -> $vps_name ($ip:$target_port)"
  else
    echo "⚠️  REVERSE PROXY CREATED, BUT ATTENTION IS REQUIRED:"
    echo "   The routing configuration was saved, but one or more live checks failed (see ⚠️  above)."
  fi
  echo "================================================================"
}
