#!/bin/bash
# End-to-end test of VPSForge on a REAL host (run as root on the Ubuntu VPS):
#   sudo bash scripts/e2e.sh
# It only creates/removes its own test container (name below) and its own
# port-forward rules; other containers are never touched.
set -uo pipefail

LIB_DIR="${LIB_DIR:-/opt/vpsforge/lib}"
T="vpsforge-e2e"
PASS=0; FAILN=0
export TERM=dumb

source "$LIB_DIR/load_vpsforge_lib.sh"
load_vpsforge_lib "$LIB_DIR"
VPSFORGE_VERSION="e2e"
get_network_info || exit 1
get_public_ip
load_settings

LOG=/tmp/vpsforge-e2e.log
: > "$LOG"

# ok "name" cmd...   -> runs cmd, prints PASS/FAIL
ok() {
  local name="$1"; shift
  if "$@" >>"$LOG" 2>&1; then PASS=$((PASS+1)); echo "PASS  $name"
  else FAILN=$((FAILN+1)); echo "FAIL  $name"; tail -4 "$LOG" | sed 's/^/        /'; fi
}
# no "name" cmd...   -> passes when cmd FAILS
no() {
  local name="$1"; shift
  if "$@" >>"$LOG" 2>&1; then FAILN=$((FAILN+1)); echo "FAIL  $name (expected failure)"
  else PASS=$((PASS+1)); echo "PASS  $name"; fi
}

# Log in over SSH with a password (SSH_ASKPASS trick, no sshpass needed).
ssh_pw() { # user pass host cmd
  local u="$1" p="$2" h="$3" askpass rc; shift 3
  askpass=$(mktemp); chmod 700 "$askpass"
  {
    echo '#!/bin/sh'
    echo 'printf "%s\n" "$E2E_PW"'   # the password comes from the environment, never written to the file
  } > "$askpass"
  E2E_PW="$p" SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force setsid \
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no -o ConnectTimeout=10 "$u@$h" "$@"
  rc=$?
  rm -f "$askpass"
  return "$rc"
}
cfg() { incus config get "$T" "$1"; }

cleanup() {
  local ip port
  ip=$(get_ip "$T" 2>/dev/null || true)
  [ -n "$ip" ] && { remove_ip "$ip"; port_forward_delete_rules_for_ip "$ip"; }
  incus delete "$T" --force >/dev/null 2>&1 || true
  incus delete "${T}-r" --force >/dev/null 2>&1 || true
  incus delete "${T}-imp" --force >/dev/null 2>&1 || true
  rm -f "$CADDY_CONF_DIR/$T.caddy" /tmp/e2e_askpass.sh 2>/dev/null
  save_iptables
}
trap cleanup EXIT

echo "   incus version: $(incus --version 2>/dev/null)"
echo "== VPSForge e2e on $(hostname) | $(. /etc/os-release; echo "$PRETTY_NAME") | $(uname -m) =="
incus delete "$T" --force >/dev/null 2>&1 || true

echo "-- create"
num=$(next_num); port=$(vps_fixed_port "$num"); ip="${NETWORK_PREFIX}.$((IP_START + num - 1))"
echo "   using num=$num ip=$ip port=$port"
start=$(date +%s)
ok "create_vps (256MB, 1 core, 3GB disk)" create_vps "$T" "$num" 256 "$port" limited limited 1 limited 3 unlimited "" "images:ubuntu/24.04" unlimited 0 0 y
echo "   creation took $(( $(date +%s) - start ))s"
ok "container RUNNING" is_vps_running "$T"
ok "metadata ip saved" test "$(cfg user.vpsforge.ip)" = "$ip"
ok "default password saved" test "$(get_vps_password "$T")" = "root"
ok "sshd listening on :22" incus exec "$T" -- sh -c 'ss -lnt | grep -q ":22 "'
ok "DNAT rule for ssh port" sh -c "iptables -t nat -S PREROUTING | grep -q -- '--dport $port -j DNAT --to-destination $ip:22'"
ok "ssh password login root" ssh_pw root root "$ip" true
# Some clouds cannot reach archive.ubuntu.com (ARM hosts use ports.ubuntu.com), so any one of these is enough.
ok "container has internet" incus exec "$T" -- sh -c 'for u in http://archive.ubuntu.com http://ports.ubuntu.com https://github.com; do curl -fsS -m 8 -o /dev/null "$u" && exit 0; done; exit 1'
ok "RAM limit applied" test "$(incus config get "$T" limits.memory)" = "256MiB"
ok "CPU limit applied" test "$(incus config get "$T" limits.cpu)" = "1"
other_ip=$(incus list -c n4 --format csv | awk -F, -v t="$T" '$1!=t && $2!="" {split($2,a," "); print a[1]; exit}')
if [ -n "$other_ip" ]; then
  no "isolation: cannot reach other VPS ($other_ip)" incus exec "$T" -- ping -c1 -W2 "$other_ip"
else
  echo "SKIP  isolation (no other VPS on this host to test against)"
fi

echo "-- users & passwords"
ok "change_vps_username" change_vps_username "$T" devuser
no "reject invalid username" change_vps_username "$T" "bad;user"
ok "change_vps_password (for devuser)" change_vps_password "$T" "N3wPass123"
ok "login with new password" ssh_pw devuser N3wPass123 "$ip" true
ok "stored password updated" test "$(get_vps_password "$T")" = "N3wPass123"
no "reject password with colon" change_vps_password "$T" "a:b"

echo "-- resources"
ok "set RAM 512" set_ram_mode_for_vps "$T" limited 512
ok "RAM is 512MiB" test "$(incus config get "$T" limits.memory)" = "512MiB"
ok "RAM unlimited" set_ram_mode_for_vps "$T" unlimited
ok "set CPU unlimited" set_cpu_mode_for_vps "$T" unlimited
no "CPU above host cores rejected" set_cpu_mode_for_vps "$T" limited 99
ok "set disk 5GB" set_disk_mode_for_vps "$T" limited 5
ok "disk limit reads 5" test "$(get_vps_disk_limit_gb "$T")" = "5"
ok "set network 100Mbit" set_network_mode_for_vps "$T" limited 100
ok "network limit reads 100" test "$(get_vps_network_limit_mbit "$T")" = "100"
ok "network unlimited" set_network_mode_for_vps "$T" unlimited
ok "traffic quota set" set_traffic_mode_for_vps "$T" limited 100 100
ok "quota check runs" check_vps_traffic_quotas
ok "traffic display" sh -c "$(declare -f get_vps_network_io_display get_vps_traffic_rx_limit_gb get_vps_traffic_tx_limit_gb); get_vps_network_io_display '$T' | grep -q '↓'"
ok "traffic unlimited" set_traffic_mode_for_vps "$T" unlimited 0 0

echo "-- port forwarding"
ok "pf add tcp 18081 -> :80" port_forward_cli add tcp 0.0.0.0 18081 "$ip" 80
ok "pf rule in iptables" sh -c "iptables -t nat -S PREROUTING | grep -q -- '--dport 18081'"
pf_lists_rule() { local out; out=$(port_forward_list_rules); grep -q 18081 <<<"$out"; }
ok "pf list prints the rule" pf_lists_rule
ok "pf rule saved in file" grep -q "18081|$ip|80" "$PORT_FORWARD_RULES_FILE"
ok "pf delete" port_forward_cli delete tcp 0.0.0.0 18081 "$ip" 80
no "pf rule gone from iptables" sh -c "iptables -t nat -S PREROUTING | grep -q -- '--dport 18081'"
ok "change ssh port" change_vps_port "$T" 9150
ok "new ssh port DNAT" sh -c "iptables -t nat -S PREROUTING | grep -q -- '--dport 9150 -j DNAT --to-destination $ip:22'"
ok "change ssh port back" change_vps_port "$T" "$port"

echo "-- snapshots"
ok "snapshot create" create_vps_snapshot "$T" e2e-snap
ok "marker file after snapshot" incus exec "$T" -- sh -c 'echo x > /root/after_snapshot'
ok "snapshot restore" restore_vps_snapshot "$T" e2e-snap
ok "restore removed later file" incus exec "$T" -- sh -c '! test -e /root/after_snapshot'
ok "snapshot delete" delete_vps_snapshot "$T" e2e-snap

echo "-- lifecycle"
ok "stop" incus stop "$T"
no "is stopped" is_vps_running "$T"
ok "start" incus start "$T"
ok "wait ready" wait_ready "$T"
ok "repair_vps_connection" repair_vps_connection "$T"
ok "ssh works after repair" ssh_pw devuser N3wPass123 "$ip" true
ok "rename" rename_vps_container "$T" "${T}-r"
ok "renamed exists" incus info "${T}-r"
ok "rename back" rename_vps_container "${T}-r" "$T"
details_shows_vps() { local out; out=$(details "$T"); grep -q "VPS DETAILS INSPECTOR" <<<"$out"; }
ok "details shows the VPS" details_shows_vps

echo "-- backup / import"
bk="$BACKUP_DIR/e2e-backup.tar"; mkdir -p "$BACKUP_DIR"; rm -f "$bk" "$bk.info"
ok "incus export" incus export "$T" "$bk"
ok "backup file exists" test -s "$bk"
ok "backup .info metadata" sh -c "incus config show '$T' --expanded > '$bk.info'"
ok "import backup under new name" import_vps_backup "$bk" "${T}-imp"
ok "imported VPS running" is_vps_running "${T}-imp"
ok "imported VPS has its own ip" test "$(get_ip "${T}-imp")" != "$ip"
imp_ip=$(get_ip "${T}-imp" 2>/dev/null || true)
[ -n "$imp_ip" ] && { remove_ip "$imp_ip"; port_forward_delete_rules_for_ip "$imp_ip"; }
ok "delete imported VPS" incus delete "${T}-imp" --force
rm -f "$bk" "$bk.info"

echo "-- reverse proxy (Caddy)"
pxy="e2e-proxy.example.com"; conf="$CADDY_CONF_DIR/$T.caddy"
add_route() { add_proxy_route "$T" "$ip" "$pxy" "$1" "$2" http; }
caddy_valid() { caddy validate --config "$MAIN_CADDYFILE"; }
route_count() { list_proxy_routes | awk -F'|' -v v="$T" '$1 == v' | wc -l; }   # only the test VPS (real VPSs may have routes)
delete_nth_route() { local line; line=$(list_proxy_routes | awk -F'|' -v v="$T" '$1 == v' | sed -n "${1}p" | awk -F'|' '{print $5}'); delete_proxy_route "$T" "$line"; }
rollback_works() {
  local b="$conf.bak"; cp "$conf" "$b"; echo "bogus {{{" >> "$conf"
  if caddy_apply_or_rollback "$conf" "$b"; then return 1; fi
  ! grep -q bogus "$conf" && caddy_valid
}
not_owned_elsewhere() { ! domain_used_by_other_vps "$pxy" "$T"; }
proxy_ip_round_trip() { update_vps_proxy_ip "$T" 10.9.9.9 && grep -q '10.9.9.9' "$conf" && update_vps_proxy_ip "$T" "$ip" && grep -q "$ip" "$conf"; }
app_listed() { list_vps_listening_ports "$T" | grep -qx 8088; }
scheme_is_http() { test "$(detect_backend_scheme "$ip" 8088)" = "http"; }

ok "caddy installed and wired to VPSForge folder" ensure_caddy_installed
ok "caddy import line present" grep -qF 'import /etc/caddy/vpsforge/*.caddy' "$MAIN_CADDYFILE"
incus exec "$T" -- sh -c 'nohup python3 -m http.server 8088 >/dev/null 2>&1 &' >/dev/null 2>&1; sleep 2
ok "wizard helper sees the app's port (8088)" app_listed
ok "wizard helper detects http" scheme_is_http
ok "add website (whole domain -> :80)" add_route "" 80
ok "config file written" grep -q "$pxy" "$conf"
ok "caddy accepts the config" caddy_valid
ok "add route /x/ -> :80" add_route "/x/" 80
ok "add route /y/ -> :8080" add_route "/y/" 8080
no "same domain + folder refused twice" add_route "/x/" 8080
ok "list shows 3 routes" test "$(route_count)" = "3"
ok "same domain refused for another VPS" not_owned_elsewhere
no "bad domain rejected" add_proxy_route "$T" "$ip" "bad domain!" "" 80 http
no "bad port rejected" add_proxy_route "$T" "$ip" "ok.example.com" "" 99999 http
ok "delete route 2 (:80) keeps :8080 (exact match)" delete_nth_route 2
ok "list shows 2 routes" test "$(route_count)" = "2"
ok ":8080 route still there" grep -q "/y/\* http://$ip:8080" "$conf"
no ":80 route is gone" grep -qE "reverse_proxy /x/\* http://$ip:80\$" "$conf"
ok "bad config is rolled back, caddy stays valid" rollback_works
ok "proxy follows an IP change" proxy_ip_round_trip
ok "caddy still valid after IP round trip" caddy_valid
ok "Caddyfile survives (not overwritten)" grep -q 'import /etc/caddy/vpsforge' "$MAIN_CADDYFILE"
ok "remove the whole website" unlink_proxy_domain "$T" "$pxy"
no "config file is gone" test -e "$conf"
ok "caddy valid with no websites" caddy_valid
ok "guest hosts entry cleaned" bash -c "! incus exec '$T' -- grep -q '$pxy' /etc/hosts"

echo "-- no leftovers after deleting VPSs"
no "no stale FORWARD rule for deleted VPS ip" bash -c "iptables -S FORWARD | grep -q -- '-d ${imp_ip:-203.0.113.9}/32'"

echo "-- cleanup"
ok "delete test VPS" sh -c "incus delete '$T' --force"

echo
echo "RESULT: $PASS passed, $FAILN failed   (log: $LOG)"
[ "$FAILN" -eq 0 ]
