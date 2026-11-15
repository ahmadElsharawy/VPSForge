#!/bin/bash
# Decide whether the VPN subscription server should serve HTTPS. It serves HTTPS ONLY with a TRUSTED
# certificate the owner installed (a real domain + Let's Encrypt): put cert.pem + key.pem in
# $VPN_SUB_DIR/.tls. We deliberately do NOT auto-make a self-signed cert: VPN apps (v2rayNG, Hiddify, ...)
# reject self-signed certs and silently fail to load the subscription, so without a domain plain HTTP is
# used instead - every app accepts it. Prints the cert directory when a trusted cert is present, else
# nothing (the caller then serves HTTP).
#   _vpn_sub_ensure_cert
_vpn_sub_ensure_cert() {
  local dir="$VPN_SUB_DIR/.tls"
  if [ -f "$dir/cert.pem" ] && [ -f "$dir/key.pem" ]; then
    echo "$dir"
  fi
  return 0
}
