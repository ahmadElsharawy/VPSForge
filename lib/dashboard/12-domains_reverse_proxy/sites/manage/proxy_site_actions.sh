#!/bin/bash
# What to do with one website route: test it, remove this route, remove the whole domain, or edit by hand.
#   proxy_site_actions "vps|domain|path|target|line"
proxy_site_actions() {
  local vps domain path target line choice scheme ip port conf answer
  IFS='|' read -r vps domain path target line <<< "$1"
  conf="$CADDY_CONF_DIR/${vps}.caddy"

  scheme="http"; [[ "$target" == https://* ]] && scheme="https"
  target="${target#*://}"; target="${target%\{}"
  ip="${target%%:*}"; port="${target##*:}"

  while true; do
    clear
    echo "================================================================"
    echo "  https://${domain}${path%\*}  ->  $vps ($ip:$port)"
    echo "================================================================"
    echo "1) Test it now (DNS, certificate, app reachable)"
    echo "2) Remove this route"
    echo "3) Remove the whole domain $domain"
    echo "4) Edit the config by hand (advanced)"
    echo "0) Back"
    read -r -p "Choice [0=Back, Enter=1]: " choice </dev/tty
    choice="${choice:-1}"
    case "$choice" in
      0) return ;;
      1)
        diagnose_domain_proxy "$vps" "$domain" "$scheme" "$ip" "$port" "$([ "$path" = "/" ] && echo "" || echo "$path")"
        pause
        ;;
      2)
        read -r -p "Remove this route? [y/N]: " answer </dev/tty
        if [[ "${answer,,}" =~ ^y ]]; then
          delete_proxy_route "$vps" "$line" && echo "Removed."
          pause; return
        fi
        ;;
      3)
        if _proxy_action_remove_domain "$vps" "$domain" "$conf"; then
          return
        fi
        ;;
      4)
        _proxy_action_edit_conf "$vps" "$conf"
        return
        ;;
      *) sleep 1 ;;
    esac
  done
}
