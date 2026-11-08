#!/bin/bash
# Guided wizard: put a domain in front of an app running inside one of your VPSs.
# Every step has a default (press Enter); 0 goes back one step.
proxy_add_site_wizard() {
  PW_VPS=""; PW_IP=""; PW_PORT=""; PW_DOMAIN=""; PW_PATH=""; PW_SCHEME="http"

  clear
  echo "================================================================"
  echo "                      ADD A DOMAIN"
  echo "================================================================"
  echo "Makes https://your-domain open an app that runs inside one of your VPSs."
  echo "(HTTPS certificates are created and renewed automatically.)"
  echo

  ensure_caddy_installed || { pause; return; }

  run_wizard proxy_wizard_step_vps proxy_wizard_step_port proxy_wizard_step_domain \
             proxy_wizard_step_path proxy_wizard_step_confirm || return

  if ! add_proxy_route "$PW_VPS" "$PW_IP" "$PW_DOMAIN" "$PW_PATH" "$PW_PORT" "$PW_SCHEME"; then
    pause; return
  fi

  echo
  echo "DONE. One last step, at your domain provider (DNS):"
  echo "   create an  A  record:   $PW_DOMAIN  ->  ${PUBLIC_IP:-your server IP}"
  echo "   (Cloudflare: both 'DNS only' and the orange cloud work)"
  echo
  diagnose_domain_proxy "$PW_VPS" "$PW_DOMAIN" "$PW_SCHEME" "$PW_IP" "$PW_PORT" "$PW_PATH"
  pause
}
