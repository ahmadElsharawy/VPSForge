#!/bin/bash
# Show how to reach a tunnel from the internet and the command to run on YOUR computer.
#   tunnel_show_connect <vps> <tunnel_port>
tunnel_show_connect() {
  local vps="${1:?vps}" tport="${2:?tunnel port}" rec lport ext domain state user
  rec=$(tunnel_get_records "$vps" | awk -F'|' -v p="$tport" '$1 == p { print; exit }')
  [ -n "$rec" ] || { echo "No tunnel on port $tport of $vps."; return 1; }
  IFS='|' read -r _ lport ext domain state <<< "$rec"
  user=$(get_vps_user "$vps")

  echo
  if [ -n "$domain" ]; then
    echo "Open:  https://$domain      (DNS: an  A  record  $domain -> ${PUBLIC_IP:-your server IP})"
  else
    echo "Open:  http://${PUBLIC_IP:-SERVER-IP}:$ext"
    echo "Note: your cloud provider's firewall (Oracle: VCN security list, Google: VPC rule) must also allow TCP port $ext."
  fi
  tunnel_connect_menu "$user" "${PUBLIC_IP:-SERVER-IP}" "$(get_vps_saved_port "$vps")" "$tport" "$lport"
}
