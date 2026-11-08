#!/bin/bash
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

  # Step 1: Caddy Service & Ingress Firewall
  echo -n "[1/4] Checking Host Caddy Service & Ingress Ports 80/443... "
  if systemctl is-active --quiet caddy; then
    iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || \
      iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || true
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
      ufw allow 80/tcp >/dev/null 2>&1 || true
      ufw allow 443/tcp >/dev/null 2>&1 || true
    fi
    save_iptables 2>/dev/null || true
    echo "OK (Caddy is running & ports 80/443 open on host)"
    if proxy_port_conflicts; then
      all_ok=0
    fi
  else
    echo "FAILED"
    echo "  ⚠️  Caddy service is NOT running on this server!"
    echo "     Run 'systemctl start caddy' and check 'journalctl -u caddy -e'."
    all_ok=0
  fi

  # Step 2: Target Backend Connectivity (Host -> Guest Container)
  echo -n "[2/4] Testing Backend Connection (${target_schema}://$ip:$target_port)... "
  if ! is_vps_running "$vps_name"; then
    echo "FAILED (Container Stopped)"
    echo "  ⚠️  VPS container '$vps_name' is currently STOPPED!"
    echo "     Caddy cannot reach a stopped container and will return 502 Bad Gateway."
    echo "     👉 FIX: Start '$vps_name' from Main Menu -> 3) Start."
    all_ok=0
  else
    local backend_ok=0
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$ip/$target_port" 2>/dev/null; then
      backend_ok=1
    elif curl -s -m 2 -k "${target_schema}://$ip:$target_port" >/dev/null 2>&1; then
      backend_ok=1
    fi

    if [ "$backend_ok" -eq 1 ]; then
      echo "OK (Backend is reachable & responding)"
    else
      echo "FAILED (Connection Refused / Unreachable)"
      all_ok=0

      local listening_info=""
      listening_info=$(incus exec "$vps_name" -- sh -c "(ss -lnt || netstat -lnt) 2>/dev/null" | grep -E "[:.]${target_port}([[:space:]]|$)" || true)

      if [ -n "$listening_info" ]; then
        if echo "$listening_info" | grep -qE "(127\.0\.0\.1|::1|localhost)"; then
          echo "  ⚠️  CRITICAL BINDING ISSUE DETECTED inside '$vps_name':"
          echo "     Your application is listening ONLY on 127.0.0.1:$target_port (Loopback only)."
          echo "     Host Caddy cannot reach 127.0.0.1 inside the container!"
          echo "     👉 FIX: Configure your application/server inside '$vps_name' to bind to 0.0.0.0:$target_port (or $ip:$target_port) instead of 127.0.0.1."
        else
          echo "  ⚠️  Port $target_port is open inside container ($listening_info), but not reachable from host bridge."
          echo "     Check internal firewall/iptables rules inside '$vps_name'."
        fi
      else
        echo "  ⚠️  NO SERVICE IS LISTENING inside '$vps_name' on port $target_port!"
        echo "     👉 FIX: Start your application/web server inside '$vps_name' on port $target_port."
      fi
    fi
  fi

  # Step 3: Public DNS Resolution
  echo -n "[3/4] Checking DNS Resolution for $domain... "
  local resolved_ip=""
  resolved_ip=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | head -n 1 || true)
  [ -n "$resolved_ip" ] || resolved_ip=$(host "$domain" 2>/dev/null | awk '/has address/ {print $NF; exit}' || true)
  [ -n "$resolved_ip" ] || resolved_ip=$(nslookup "$domain" 2>/dev/null | awk '/^Address: / {print $2}' | tail -n 1 || true)

  if [ -n "$resolved_ip" ]; then
    if [ "$resolved_ip" = "$PUBLIC_IP" ]; then
      echo "OK ($domain -> $PUBLIC_IP)"
    else
      echo "WARNING"
      echo "  ⚠️  DNS IP MISMATCH:"
      echo "     $domain currently resolves to: $resolved_ip"
      echo "     This server's public IP is:    $PUBLIC_IP"
      echo "     Let's Encrypt / ZeroSSL will FAIL to validate ACME challenges until DNS points to $PUBLIC_IP."
      echo "     (If this domain is behind Cloudflare's orange-cloud proxy, a different IP is expected.)"
      all_ok=0
    fi
  else
    echo "WARNING"
    echo "  ⚠️  Could not resolve DNS for '$domain'."
    echo "     Ensure you have created an A Record pointing '$domain' -> '$PUBLIC_IP'."
    all_ok=0
  fi

  # Step 4: SSL / ACME Validation Check & Cloud Firewall Guidance
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
    all_ok=0
  else
    echo "OK (Caddy is issuing / managing SSL certificates)"
  fi

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
