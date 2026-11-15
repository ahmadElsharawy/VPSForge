#!/bin/bash
# Make sure the permanent web server of one VPN runs (systemd service vpsforge-vpnsub-<port>, starts
# again after a reboot) on TCP <VPN port + 1>, and that this server's firewall lets it be reached.
# It serves the subscription links and the short-lived QR pages (vpn_sub_server.py).
#   vpn_sub_server_ensure <vps>
vpn_sub_server_ensure() {
  local vps="${1:?vps}" ext port dir unit file helper want
  ext=$(vpn_get_port "$vps")
  [ -n "$ext" ] || return 1
  port=$((ext + 1)); dir="$VPN_SUB_DIR/$ext"; unit="vpsforge-vpnsub-$ext"
  file="/etc/systemd/system/$unit.service"
  helper="${LIB_DIR:-/opt/vpsforge/lib}/core/proxy/vpn/vpn_sub_server.py"
  [ -f "$helper" ] || { echo "ERROR: $helper is missing."; return 1; }
  mkdir -p "$dir/subs" "$dir/pages" && chmod 700 "$dir" || return 1
  # Serve the subscription over HTTPS (self-signed, by IP) so the token is not sent in clear. If the
  # certificate cannot be made (no openssl), fall back to plain HTTP rather than failing.
  local certdir
  certdir=$(_vpn_sub_ensure_cert 2>/dev/null || true)
  if [ -n "$certdir" ]; then
    want="ExecStart=/usr/bin/python3 $helper $dir $port $certdir"
  else
    want="ExecStart=/usr/bin/python3 $helper $dir $port"
  fi
  # upgrade from v3.5.1 and older: a short-lived page (vpn_once_server.py) may still hold the port.
  # Stop it and wait until its wrapper has closed ITS firewall opening, so ours below is not removed.
  local old_pids n=0
  old_pids=$(pgrep -f "[v]pn_once_server.py .* $port ")
  if [ -n "$old_pids" ]; then
    kill $old_pids 2>/dev/null
    # the python page: "... vpn_once_server.py <files> <secret> PORT ..."; its wrapper: "bash -c ... _ PORT .../vpn_once_server.py ..."
    while pgrep -f "[v]pn_once_server.py .* $port " >/dev/null || pgrep -f "[_] $port .*vpn_once_server.py" >/dev/null; do
      n=$((n + 1)); [ "$n" -ge 20 ] && break
      sleep 0.5
    done
    sleep 1
  fi
  if ! grep -qxF "$want" "$file" 2>/dev/null; then
    if ! systemctl is-active --quiet "$unit" && [ -n "$(host_port_owner "$port" tcp)" ]; then
      echo "ERROR: TCP $port is used by another program, so the subscription links cannot be served."
      return 1
    fi
    {
      echo "[Unit]"
      echo "Description=VPSForge VPN subscription links (port $port)"
      echo "After=network-online.target"
      echo "[Service]"
      echo "$want"
      echo "Restart=always"
      echo "RestartSec=3"
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } > "$file"
    systemctl daemon-reload
    systemctl enable "$unit" >/dev/null 2>&1
    systemctl restart "$unit" || return 1
  fi
  systemctl is-active --quiet "$unit" || systemctl restart "$unit" || return 1
  if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
    iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
    save_iptables
  fi
  return 0
}
