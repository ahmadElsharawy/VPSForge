#!/bin/bash
# Print the script that lives inside the VPS (/etc/vpsforge-vpn/apply.sh).
# It builds Xray's config.json from devices.txt (devices that are switched off are left out),
# checks it, and (re)starts the vpsforge-vpn service, which also starts again after a reboot.
# Run inside the VPS with:  PORT=<8443> SNI=<site> API=<10085> sh apply.sh
vpn_guest_apply_script() {
  cat <<'EOF_APPLY'
#!/bin/sh
set -e
D=/etc/vpsforge-vpn
cd "$D"
umask 077
touch devices.txt
# count what was used so far: restarting Xray clears its counters
if [ -f check.sh ]; then sh check.sh collect >/dev/null 2>&1 || true; fi
clients=""
while IFS='|' read -r name id mode f4 f5 limit expires state; do
  [ -n "$id" ] || continue
  [ -z "$state" ] || [ "$state" = "on" ] || continue   # over its data limit or out of days
  c="{\"id\":\"$id\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$name\",\"level\":0}"
  if [ -z "$clients" ]; then clients="$c"; else clients="$clients,$c"; fi
done < devices.txt
priv=$(cat server.key)
sid=$(cat short.id)
cat > config.new.json <<EOC
{
  "log": {"loglevel": "warning"},
  "stats": {},
  "api": {"tag": "api", "services": ["StatsService"]},
  "policy": {"levels": {"0": {"statsUserUplink": true, "statsUserDownlink": true}}},
  "inbounds": [
    {"tag": "vless-in", "listen": "0.0.0.0", "port": $PORT, "protocol": "vless",
     "settings": {"clients": [$clients], "decryption": "none"},
     "streamSettings": {"network": "tcp", "security": "reality",
       "realitySettings": {"dest": "$SNI:443", "serverNames": ["$SNI"],
         "privateKey": "$priv", "shortIds": ["$sid"]}},
     "sniffing": {"enabled": false}},
    {"tag": "api", "listen": "127.0.0.1", "port": $API, "protocol": "dokodemo-door",
     "settings": {"address": "127.0.0.1"}}
  ],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}, {"protocol": "blackhole", "tag": "block"}],
  "routing": {"rules": [{"type": "field", "inboundTag": ["api"], "outboundTag": "api"}]}
}
EOC
out=$(/usr/local/bin/xray run -test -c config.new.json 2>&1) || { echo "$out" | tail -3; rm -f config.new.json; exit 1; }
mv -f config.new.json config.json
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  if [ ! -f /etc/systemd/system/vpsforge-vpn.service ]; then
    {
      echo "[Unit]"
      echo "Description=VPSForge VPN (Xray)"
      echo "After=network-online.target"
      echo "[Service]"
      echo "ExecStart=/usr/local/bin/xray run -c $D/config.json"
      echo "Restart=on-failure"
      echo "LimitNOFILE=1048576"
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } > /etc/systemd/system/vpsforge-vpn.service
    systemctl daemon-reload
    systemctl enable vpsforge-vpn >/dev/null 2>&1
  fi
  systemctl restart vpsforge-vpn
elif command -v rc-service >/dev/null 2>&1; then
  if [ ! -f /etc/init.d/vpsforge-vpn ]; then
    {
      echo "#!/sbin/openrc-run"
      echo "command=/usr/local/bin/xray"
      echo "command_args=\"run -c $D/config.json\""
      echo "supervisor=supervise-daemon"
    } > /etc/init.d/vpsforge-vpn
    chmod 755 /etc/init.d/vpsforge-vpn
    rc-update add vpsforge-vpn default >/dev/null 2>&1 || true
  fi
  rc-service vpsforge-vpn restart >/dev/null 2>&1 || rc-service vpsforge-vpn start
else
  pkill -x xray 2>/dev/null || true
  nohup /usr/local/bin/xray run -c "$D/config.json" >/dev/null 2>&1 &
fi
EOF_APPLY
}
