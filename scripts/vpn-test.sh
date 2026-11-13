#!/bin/bash
# VPN (Xray, VLESS + Reality) test on a REAL host:   sudo bash scripts/vpn-test.sh
# Makes two test VPSs (vpnt-s = VPN server, vpnt-c = a "device" running an Xray client),
# connects through the VPN, checks limits, the QR page and the clean removal.
# The two test VPSs are kept for the next run (faster); CLEAN=1 removes them at the end.
set -uo pipefail
LIB_DIR="${LIB_DIR:-/opt/vpsforge/lib}"
S=vpnt-s; C=vpnt-c; PORT=51990
PASS=0; FAILN=0
export TERM=dumb
source "$LIB_DIR/load_vpsforge_lib.sh"; load_vpsforge_lib "$LIB_DIR"
get_network_info || exit 1; get_public_ip; load_settings
LOG=/tmp/vpsforge-vpn-test.log; : > "$LOG"
for f in "$(dirname "$0")/lib/vpn-test"/*.sh; do . "$f"; done
vpn_remove "$S" >/dev/null 2>&1 || true   # leftovers of an earlier run (the VPSs themselves are reused)

echo "-- create two test VPSs"
for v in "$S" "$C"; do
  if incus info "$v" >/dev/null 2>&1; then
    incus start "$v" >/dev/null 2>&1 || true; echo "PASS  reuse $v"
  else
    n=$(next_num); ok "create $v" create_vps "$v" "$n" 512 "$(vps_fixed_port "$n")" limited unlimited "" unlimited "" unlimited "" "$VPS_IMAGE" unlimited 0 0 n
  fi
done
SIP=$(get_ip "$S"); CIP=$(get_ip "$C")
# VPSForge keeps VPSs apart (isolation); a real device comes from outside the server.
# For this test only, let the "device" VPS reach the VPN VPS (removed again at the end).
[ -n "$SIP" ] && [ -n "$CIP" ] && iso_open

echo "-- create the VPN"
TSNI="${VPN_TEST_SNI:-$VPN_SNI}"   # VPN_TEST_SNI=www.microsoft.com tests a chosen disguise site
ok "the disguise site speaks TLS 1.3 + HTTP/2" vpn_sni_supported "$TSNI"
ok "vpn_create" vpn_create "$S" "$PORT" "$TSNI"
ok "SNI saved on the VPS" test "$(vpn_get_sni "$S")" = "$TSNI"
ok "Xray runs inside the VPS" incus exec "$S" -- pgrep -x xray
ok "VPN port saved on the VPS" test "$(vpn_get_port "$S")" = "$PORT"
ok "TCP $PORT forwarded to the VPS" t_fwd
ok "forward listed in menu 11 file" grep -q "^tcp|0.0.0.0|$PORT|$SIP|$PORT" "$PORT_FORWARD_RULES_FILE"
ok "vpn_all_vps lists it" t_listed
no "a second VPN on the same VPS is refused" vpn_create "$S" 51980
ok "the first VPN is still there" incus exec "$S" -- pgrep -x xray

echo "-- devices"
ok "add device phone (unlimited)" vpn_add_device "$S" phone 0 0
ok "add device laptop (50 GB, 30 days)" vpn_add_device "$S" laptop 50 30
no "same name refused" vpn_add_device "$S" laptop 0 0
no "bad name refused" vpn_add_device "$S" "bad name" 0 0
ok "2 devices listed" test "$(vpn_list_devices "$S" | wc -l)" = "2"
LINK=$(vpn_device_link "$S" phone)
ok "the link carries the chosen SNI" grep -q "sni=$TSNI&" <<< "$LINK"
ok "phone link: vless, Reality, name IP-VPS-unl-unl" t_link
ok "laptop link name IP-VPS-30d-50GB" t_label
ok "QR code is printed" t_qr

echo "-- connect a device (Xray client inside the server, straight to the VPS address)"
ARCH=64; [ "$(uname -m)" = "aarch64" ] && ARCH=arm64-v8a
in_c 'test -x /usr/local/bin/xray' && echo "PASS  Xray client already on the device" || ok "install Xray client on the device" in_c "export DEBIAN_FRONTEND=noninteractive; apt-get -o Acquire::ForceIPv4=true update -qq && apt-get -o Acquire::ForceIPv4=true install -y -qq --no-install-recommends curl unzip ca-certificates >/dev/null && t=\$(mktemp -d) && curl -4 -fsSL -o \$t/x.zip https://github.com/XTLS/Xray-core/releases/download/$VPN_XRAY_VERSION/Xray-linux-$ARCH.zip && unzip -o -q \$t/x.zip xray -d /usr/local/bin"
# client config from a device's link -> socks proxy on 127.0.0.1:1080 inside the device
client_up phone
ok "phone goes online through the VPN" online
in_c 'curl -4 -s -m 40 --socks5-hostname 127.0.0.1:1080 -o /dev/null https://proof.ovh.net/files/100Mb.dat' >/dev/null 2>&1
ok "its traffic is counted (MB used, last active)" t_used

echo "-- data limit and days"
ok "give phone a 1 GB limit" vpn_set_device_limits "$S" phone 1 0
incus exec "$S" -- sh -c "awk -F'|' -v OFS='|' '\$1 == \"phone\" { \$2 = 2000000000 } { print }' $VPN_GUEST_DIR/usage.txt > /tmp/u && mv /tmp/u $VPN_GUEST_DIR/usage.txt" </dev/null
vpn_check_limits
ok "phone is switched off after its 1 GB" t_state phone off-data
no "phone can no longer go online" online
ok "renew phone (unlimited)" vpn_set_device_limits "$S" phone 0 0
ok "phone is on again" t_state phone on
client_up phone
ok "phone goes online again" online
ok "give laptop 1 day" vpn_set_device_limits "$S" laptop 0 1
incus exec "$S" -- sh -c "awk -F'|' -v OFS='|' '\$1 == \"laptop\" { \$7 = 1000 } { print }' $VPN_GUEST_DIR/devices.txt > /tmp/d && mv /tmp/d $VPN_GUEST_DIR/devices.txt" </dev/null
vpn_check_limits
ok "laptop is switched off when its days are over" t_state laptop off-time
client_up laptop
no "laptop can no longer go online" online
ok "renew laptop for 30 days" vpn_set_device_limits "$S" laptop 0 30
client_up laptop
ok "laptop goes online again" online
no "bad limit refused" vpn_set_device_limits "$S" phone abc 1

echo "-- QR page"
url=$(vpn_share_link "$S" phone 1)
path="/${url#http://*/}"
P2=$((PORT + 1))
ok "page address printed" test -n "$url"
ok "page shows the QR code" t_page
ok "page shows the link to copy" t_page_link
no "wrong secret is refused" curl -fsS -m 5 "http://127.0.0.1:$P2/wrong/"
ok "firewall opening while the page lives" t_in
exec 7<>"/dev/tcp/127.0.0.1/$P2"   # a browser-like connection that never sends anything
echo "      waiting 65 s for the page to expire (with a connection left open)..."; sleep 65
exec 7>&- 7<&-
no "page is gone after its time" curl -fsS -m 5 "http://127.0.0.1:$P2$path"
no "firewall opening closed again" t_in
no "no copy of the link left" t_copy_left

echo "-- remove"
ok "remove a device" vpn_remove_device "$S" laptop
ok "1 device left" test "$(vpn_list_devices "$S" | wc -l)" = "1"
no "removed device is gone from Xray" incus exec "$S" -- grep -q '"email":"laptop"' "$VPN_GUEST_DIR/config.json"
ok "remove the VPN" vpn_remove "$S"
no "Xray stopped" incus exec "$S" -- pgrep -x xray
no "Xray program removed" incus exec "$S" -- test -e /usr/local/bin/xray
no "VPN record is gone" test -n "$(vpn_get_port "$S")"
no "TCP forward is gone" t_fwd
no "forward file is clean" grep -q "|$PORT|" "$PORT_FORWARD_RULES_FILE"

echo "-- interrupted create leaves nothing"
( vpn_create "$S" "$PORT" >/dev/null 2>&1 & p=$!; sleep 2; kill -TERM $p; wait $p ) 2>/dev/null
sleep 2
no "no VPN record after an interrupted create" test -n "$(vpn_get_port "$S")"
no "no forward after an interrupted create" t_fwd

echo "-- cleanup"
[ -n "$SIP" ] && [ -n "$CIP" ] && iso_close
vpn_remove "$S" >/dev/null 2>&1 || true
[ "${CLEAN:-0}" = "1" ] && cleanup
echo "RESULT: $PASS passed, $FAILN failed   (log: $LOG)"
