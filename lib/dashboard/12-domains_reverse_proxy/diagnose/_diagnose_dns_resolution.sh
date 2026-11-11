#!/bin/bash
# Verify DNS resolution for the domain matches the host public IP.
#   _diagnose_dns_resolution <domain>
_diagnose_dns_resolution() {
  local domain="$1"
  echo -n "[3/4] Checking DNS Resolution for $domain... "
  local resolved_ip=""
  resolved_ip=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | head -n 1 || true)
  [ -n "$resolved_ip" ] || resolved_ip=$(host "$domain" 2>/dev/null | awk '/has address/ {print $NF; exit}' || true)
  [ -n "$resolved_ip" ] || resolved_ip=$(nslookup "$domain" 2>/dev/null | awk '/^Address: / {print $2}' | tail -n 1 || true)

  if [ -n "$resolved_ip" ]; then
    if [ "$resolved_ip" = "$PUBLIC_IP" ]; then
      echo "OK ($domain -> $PUBLIC_IP)"
      return 0
    else
      echo "WARNING"
      echo "  ⚠️  DNS IP MISMATCH:"
      echo "     $domain currently resolves to: $resolved_ip"
      echo "     This server's public IP is:    $PUBLIC_IP"
      echo "     Let's Encrypt / ZeroSSL will FAIL to validate ACME challenges until DNS points to $PUBLIC_IP."
      echo "     (If this domain is behind Cloudflare's orange-cloud proxy, a different IP is expected.)"
      return 1
    fi
  else
    echo "WARNING"
    echo "  ⚠️  Could not resolve DNS for '$domain'."
    echo "     Ensure you have created an A Record pointing '$domain' -> '$PUBLIC_IP'."
    return 1
  fi
}
