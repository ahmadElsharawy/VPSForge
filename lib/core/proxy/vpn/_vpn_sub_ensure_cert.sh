#!/bin/bash
# Make (once) the self-signed TLS certificate the VPN subscription servers use, so the subscription
# token is served over HTTPS instead of clear HTTP. One cert for the whole server, named after its
# public IP (no domain here); regenerated only if missing or the public IP changed. Prints the cert
# directory on success, nothing on failure.
#   _vpn_sub_ensure_cert
_vpn_sub_ensure_cert() {
  local dir="$VPN_SUB_DIR/.tls" ip="${PUBLIC_IP:-}"
  [ -n "$ip" ] || { get_public_ip >/dev/null 2>&1 || true; ip="${PUBLIC_IP:-}"; }
  [ -n "$ip" ] || return 1
  command -v openssl >/dev/null 2>&1 || return 1
  mkdir -p "$dir" 2>/dev/null && chmod 700 "$dir" 2>/dev/null || return 1
  # Reuse the existing cert unless the public IP changed (the cert pins the IP in its SAN).
  if [ -f "$dir/cert.pem" ] && [ -f "$dir/key.pem" ] && [ "$(cat "$dir/ip" 2>/dev/null)" = "$ip" ]; then
    echo "$dir"; return 0
  fi
  if openssl req -x509 -newkey rsa:2048 -nodes -keyout "$dir/key.pem" -out "$dir/cert.pem" \
      -days 3650 -subj "/CN=$ip" -addext "subjectAltName=IP:$ip" >/dev/null 2>&1; then
    chmod 600 "$dir/key.pem" "$dir/cert.pem" 2>/dev/null || true
    echo "$ip" > "$dir/ip"
    echo "$dir"; return 0
  fi
  return 1
}
