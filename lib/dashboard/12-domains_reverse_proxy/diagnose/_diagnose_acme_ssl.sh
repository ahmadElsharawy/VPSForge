#!/bin/bash
# Inspect Caddy ACME certificate logs for validation errors and display firewall guidance.
#   _diagnose_acme_ssl <domain>
_diagnose_acme_ssl() {
  local domain="$1"
  echo -n "[4/4] Checking Let's Encrypt / ACME Certificate Status... "
  sleep 2
  local cert_log=""
  cert_log=$(journalctl -u caddy -n 30 --no-pager 2>/dev/null | grep -i "$domain" | grep -iE "(error|failed|could not get cert|challenge|tls-alpn|http-01)" | tail -n 2 || true)

  if [ -n "$cert_log" ]; then
    echo "WARNING / ACME VALIDATION FAILED"
    echo "  ⚠️  Caddy ACME Error Logs:"
    echo "     $cert_log"
    echo
    echo "  💡 IMPORTANT CLOUD FIREWALL REQUIREMENT:"
    echo "     If this server is hosted on Oracle Cloud (OCI), AWS EC2, GCP, Azure, or Hetzner:"
    echo "     You MUST open Ingress Ports 80 (HTTP) and 443 (HTTPS) in your Cloud Provider's Security List / Security Group!"
    echo "     Otherwise, Let's Encrypt's verification servers cannot reach Caddy from the internet -> ERR_CONNECTION_TIMED_OUT."
    return 1
  fi

  echo "OK (Caddy is issuing / managing SSL certificates)"
  return 0
}
