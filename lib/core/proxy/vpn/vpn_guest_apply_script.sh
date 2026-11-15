#!/bin/bash
# Print the script that lives inside the VPS (/etc/vpsforge-vpn/apply.sh).
# It builds Xray's config.json (VLESS+Reality and VLESS+TLS inbounds) and Hysteria2's hy.yaml from
# devices.txt (devices that are switched off are left out of all three), checks the Xray config,
# and (re)starts the vpsforge-vpn (Xray) and vpsforge-hy2 (Hysteria2) services, which also start
# again after a reboot. A failing config never takes down the service that already works.
# Run inside the VPS with:
#   PORT=<8443> SNI=<site> API=<10085> TLS_PORT=<18443> HY_PORT=<18444> HY_MASQ=<url> sh apply.sh
vpn_guest_apply_script() {
  cat <<'EOF_APPLY'
#!/bin/sh
set -e
D=/etc/vpsforge-vpn
cd "$D"
umask 077
# The settings come from the server (vpn_guest_apply). They are saved here, so a run started from
# inside the VPS (check.sh switching a device off) builds exactly the same configs.
if [ -n "${PORT:-}" ] && [ -n "${TLS_PORT:-}" ] && [ -n "${HY_PORT:-}" ] && [ -n "${HY_MASQ:-}" ]; then
  {
    echo "PORT='$PORT'"
    echo "SNI='$SNI'"
    echo "API='$API'"
    echo "TLS_PORT='$TLS_PORT'"
    echo "HY_PORT='$HY_PORT'"
    echo "HY_MASQ='$HY_MASQ'"
  } > apply.env.new
  mv -f apply.env.new apply.env
elif [ -f apply.env ]; then
  . ./apply.env
fi
for v in PORT SNI API TLS_PORT HY_PORT HY_MASQ; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || { echo "ERROR: VPN setting $v is missing; nothing was changed." >&2; exit 1; }
done
touch devices.txt
# count what was used so far: restarting Xray clears its counters
if [ -f check.sh ]; then sh check.sh collect >/dev/null 2>&1 || true; fi
clients=""
tls_clients=""
hy_users=""
while IFS='|' read -r name id mode f4 f5 limit expires state; do
  [ -n "$id" ] || continue
  [ -z "$state" ] || [ "$state" = "on" ] || continue   # over its data limit or out of days
  c="{\"id\":\"$id\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$name\",\"level\":0}"
  if [ -z "$clients" ]; then clients="$c"; else clients="$clients,$c"; fi
  t="{\"id\":\"$id\",\"email\":\"$name\",\"level\":0}"   # the TLS inbound has no flow: apps connect to it without one
  if [ -z "$tls_clients" ]; then tls_clients="$t"; else tls_clients="$tls_clients,$t"; fi
  hy_users="$hy_users$name|$id
"
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
    {"tag": "vless-tls-in", "listen": "0.0.0.0", "port": $TLS_PORT, "protocol": "vless",
     "settings": {"clients": [$tls_clients], "decryption": "none"},
     "streamSettings": {"network": "tcp", "security": "tls",
       "tlsSettings": {"alpn": ["http/1.1"],
         "certificates": [{"certificateFile": "$D/tls.crt", "keyFile": "$D/tls.key"}]}},
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
# Xray service (VLESS+Reality and VLESS+TLS)
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
# Hysteria2: its own service, so a problem here never stops Xray. A problem is only reported.
if [ -z "$hy_users" ]; then
  # no device is on: Hysteria2 refuses an empty user list, so it is simply stopped
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then systemctl stop vpsforge-hy2 >/dev/null 2>&1 || true
  elif command -v rc-service >/dev/null 2>&1; then rc-service vpsforge-hy2 stop >/dev/null 2>&1 || true
  else pkill -x hysteria 2>/dev/null || true; fi
  exit 0
fi
{
  echo "listen: :$HY_PORT"
  echo "tls:"
  echo "  cert: $D/hy.crt"
  echo "  key: $D/hy.key"
  echo "auth:"
  echo "  type: command"
  echo "  command: $D/hy_auth.sh"
  echo "masquerade:"
  echo "  type: proxy"
  echo "  proxy:"
  echo "    url: $HY_MASQ"
  echo "    rewriteHost: true"
  # like Xray: VPN users reach the internet only, never this server, the other VPSs or the cloud metadata service
  echo "acl:"
  echo "  inline:"
  for net in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 ::1/128 fc00::/7 fe80::/10; do
    echo "    - reject($net)"
  done
  echo "    - direct(all)"
} > hy.yaml.new
# Hysteria2 login: apps send either "<uuid>" or "<name>:<uuid>" (v2rayNG and the official
# client differ), so a small script accepts both. It prints the device name (used as its id).
printf '%s' "$hy_users" > hy_users.new
mv -f hy_users.new hy_users.txt
cat > hy_auth.sh.new <<'EOA'
#!/bin/sh
# called by Hysteria2 as: hy_auth.sh <client_addr> <auth> <tx>; exit 0 = allowed
a=$(printf '%s' "$2" | sed 's/%3[Aa]/:/g')
id=${a##*:}
[ -n "$id" ] || exit 1
name=$(awk -F'|' -v id="$id" '$2 == id { print $1; exit }' "$(dirname "$0")/hy_users.txt")
[ -n "$name" ] || exit 1
case "$a" in *:*) [ "${a%:*}" = "$name" ] || exit 1;; esac
echo "$name"
EOA
chmod 755 hy_auth.sh.new
mv -f hy_auth.sh.new hy_auth.sh
mv -f hy.yaml.new hy.yaml
hy_ok=1
if [ ! -x /usr/local/bin/hysteria ]; then
  hy_ok=0
elif command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  if [ ! -f /etc/systemd/system/vpsforge-hy2.service ]; then
    {
      echo "[Unit]"
      echo "Description=VPSForge VPN (Hysteria2)"
      echo "After=network-online.target"
      echo "[Service]"
      echo "ExecStart=/usr/local/bin/hysteria server -c $D/hy.yaml"
      echo "Restart=on-failure"
      echo "LimitNOFILE=1048576"
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } > /etc/systemd/system/vpsforge-hy2.service
    systemctl daemon-reload
    systemctl enable vpsforge-hy2 >/dev/null 2>&1
  fi
  systemctl restart vpsforge-hy2 || hy_ok=0
elif command -v rc-service >/dev/null 2>&1; then
  if [ ! -f /etc/init.d/vpsforge-hy2 ]; then
    {
      echo "#!/sbin/openrc-run"
      echo "command=/usr/local/bin/hysteria"
      echo "command_args=\"server -c $D/hy.yaml\""
      echo "supervisor=supervise-daemon"
    } > /etc/init.d/vpsforge-hy2
    chmod 755 /etc/init.d/vpsforge-hy2
    rc-update add vpsforge-hy2 default >/dev/null 2>&1 || true
  fi
  rc-service vpsforge-hy2 restart >/dev/null 2>&1 || rc-service vpsforge-hy2 start >/dev/null 2>&1 || hy_ok=0
else
  pkill -x hysteria 2>/dev/null || true
  nohup /usr/local/bin/hysteria server -c "$D/hy.yaml" >/dev/null 2>&1 &
fi
[ "$hy_ok" = 1 ] || echo "WARNING: Hysteria2 did not start (Xray is running)." >&2
EOF_APPLY
}
