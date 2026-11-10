#!/bin/bash
# Offline unit tests for the pure-logic parts of VPSForge (no incus/root needed).
#   scripts/test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0; failn=0
t() { # t "description" expected actual
  if [ "$2" = "$3" ]; then pass=$((pass+1)); else failn=$((failn+1)); echo "FAIL: $1 (expected '$2', got '$3')"; fi
}

LIB_DIR="$ROOT/lib"
source "$LIB_DIR/load_vpsforge_lib.sh"
load_vpsforge_lib "$LIB_DIR"

# ram_mb
t "ram MiB"  512  "$(ram_mb 512MiB)"
t "ram GiB"  2048 "$(ram_mb 2GiB)"
t "ram unlimited" 0 "$(ram_mb Unlimited)"

# forward rules read from backups must be safe
is_valid_port_forward_rule tcp "" 8080 80 && r=ok || r=bad; t "rule ok" ok "$r"
is_valid_port_forward_rule tcp "" 22 22 && r=ok || r=bad; t "rule host ssh port refused" bad "$r"
is_valid_port_forward_rule tcp "1.2.3.4 -j ACCEPT" 8080 80 && r=ok || r=bad; t "rule ip injection refused" bad "$r"
is_valid_port_forward_rule icmp "" 8080 80 && r=ok || r=bad; t "rule bad proto refused" bad "$r"
is_valid_port_forward_rule udp 0.0.0.0 70000 80 && r=ok || r=bad; t "rule port range" bad "$r"

# usernames
is_valid_username "alice"     && r=ok || r=bad; t "user alice" ok "$r"
is_valid_username "a'; rm -rf" && r=ok || r=bad; t "user injection" bad "$r"
is_valid_username "1abc"      && r=ok || r=bad; t "user digit-first" bad "$r"
is_valid_username ""          && r=ok || r=bad; t "user empty" bad "$r"

# fixed ports
t "port num 1" 9001 "$(vps_fixed_port 1)"
t "port num 12" 9012 "$(vps_fixed_port 12)"
p=$(vps_fixed_port custom); [[ "$p" =~ ^9[0-9]{3}$ ]] && r=ok || r=bad; t "port hash range" ok "$r"

# number selection parser
parse_number_selection "1,3" 5;   t "parse 1,3" "1 3" "${SELECTED_NUMS[*]}"
parse_number_selection "2-4" 5;   t "parse 2-4" "2 3 4" "${SELECTED_NUMS[*]}"
parse_number_selection "a" 3;     t "parse all" "1 2 3" "${SELECTED_NUMS[*]}"
parse_number_selection "9" 3 && r=ok || r=bad; t "parse out of range" bad "$r"
parse_number_selection "0" 3 && r=ok || r=bad; t "parse zero" bad "$r"

# image candidates
t "normalize minimal" "images:ubuntu/24.04" "$(normalize_image_alias images:ubuntu/24.04/minimal)"
first=$(resolve_image_candidates "24.04" | head -1); t "candidates first" "24.04" "$first"

debian_c=$(resolve_image_candidates images:debian/12 | tr '
' ' ')
case "$debian_c" in *ubuntu*) r=bad;; *) r=ok;; esac; t "debian choice never falls back to ubuntu" ok "$r"
ubuntu_c=$(resolve_image_candidates images:ubuntu/jammy | tr '
' ' ')
case "$ubuntu_c" in *"images:ubuntu/noble"*) r=ok;; *) r=bad;; esac; t "ubuntu choice keeps its fallbacks" ok "$r"

# check_fixed_port_available must work with POSIX awk (mawk/busybox/gawk)
iptables() { cat <<'EOF'
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:9001 to:10.0.0.101:22
EOF
}
check_fixed_port_available vps2 10.0.0.102 9001 >/dev/null && r=ok || r=bad; t "port conflict detected" bad "$r"
check_fixed_port_available vps1 10.0.0.101 9001 >/dev/null && r=ok || r=bad; t "port same owner ok" ok "$r"
check_fixed_port_available vps3 10.0.0.103 9003 >/dev/null && r=ok || r=bad; t "port free ok" ok "$r"
unset -f iptables

# dashboard helper
out=$(echo '[{"name":"vps1","status":"Running","config":{"limits.cpu":"2","user.vpsforge.ip":"10.0.0.101"},"expanded_config":{"limits.memory":"512MiB"},"state":{"memory":{"usage":104857600},"network":{"eth0":{"counters":{"bytes_received":2048,"bytes_sent":1048576}}}},"devices":{}}]' \
  | python3 "$ROOT/lib/dashboard/dashboard_helper.py" / 1000 off 10 1.2.3.4 vX --only-table 2>&1)
case "$out" in *vps1*100MB*512MB*) r=ok;; *) r=bad; echo "$out";; esac
t "dashboard row renders" ok "$r"

# --- reverse-proxy helpers (temporary Caddy folder, no caddy binary needed) ---
CADDY_CONF_DIR=$(mktemp -d); MAIN_CADDYFILE="$CADDY_CONF_DIR/Caddyfile"
printf 'a.example.com {
    reverse_proxy http://10.0.0.5:80
    reverse_proxy /api/* https://10.0.0.5:8443 {
        transport http {
            tls_insecure_skip_verify
        }
    }
}
' > "$CADDY_CONF_DIR/vps1.caddy"
update_vps_proxy_ip vps1 10.0.0.9
t "proxy ip: root route updated" 1 "$(grep -c 'http://10.0.0.9:80' "$CADDY_CONF_DIR/vps1.caddy")"
t "proxy ip: path route updated, https kept" 1 "$(grep -c 'reverse_proxy /api/\* https://10.0.0.9:8443' "$CADDY_CONF_DIR/vps1.caddy")"
t "proxy ip: old ip gone" 0 "$(grep -c '10.0.0.5' "$CADDY_CONF_DIR/vps1.caddy")"
t "domain owner found" vps1 "$(domain_used_by_other_vps a.example.com vps2)"
domain_used_by_other_vps a.example.com vps1 >/dev/null && r=bad || r=ok; t "domain not 'other' for its owner" ok "$r"
domain_used_by_other_vps nothere.example.com vps2 >/dev/null && r=bad || r=ok; t "unused domain is free" ok "$r"
printf '# my caddy
{
    email me@x.com
}
example.org {
}
' > "$MAIN_CADDYFILE"
cloudflare_has_foreign_global_block "$MAIN_CADDYFILE" && r=yes || r=no; t "detect user's global block" yes "$r"
printf '# BEGIN VPSFORGE CLOUDFLARE
{
    servers {
    }
}
# END VPSFORGE CLOUDFLARE
example.org {
}
' > "$MAIN_CADDYFILE"
cloudflare_has_foreign_global_block "$MAIN_CADDYFILE" && r=yes || r=no; t "own block is not foreign" no "$r"
cloudflare_remove_block "$MAIN_CADDYFILE"
t "own block removed, rest kept" "example.org {" "$(grep -v '^$' "$MAIN_CADDYFILE" | head -1)"
routes=$(list_proxy_routes)
t "list_proxy_routes finds both routes" 2 "$(echo "$routes" | grep -c .)"
t "list_proxy_routes root route" "vps1|a.example.com|/|http://10.0.0.9:80|2" "$(echo "$routes" | sed -n 1p)"
t "list_proxy_routes path route" "vps1|a.example.com|/api/*|https://10.0.0.9:8443|3" "$(echo "$routes" | sed -n 2p)"
rm -rf "$CADDY_CONF_DIR"

# --- remembered defaults (last answer becomes the default) ---
PREFS_FILE=$(mktemp)
t "pref fallback when nothing saved" 7 "$(pref_get ram_value 7)"
pref_set ram_value 512
t "pref returns the saved value" 512 "$(pref_get ram_value 7)"
pref_set ram_value 256
t "a new answer replaces the old one" 256 "$(pref_get ram_value 7)"
t "only one line per key" 1 "$(grep -c '^ram_value=' "$PREFS_FILE")"
pref_set bad-key x && r=bad || r=ok; t "bad key refused" ok "$r"
# the shared resource question: Enter repeats the last limit
ask_in_test() { printf '2
512
' | ask_mode_and_value vpsX ram RAM RAM MB "in MB" is_valid_ram_value >/dev/null; echo "$RAM_MODE_RESULT $RAM_VALUE_RESULT"; }
pref_set ram_mode 1; pref_set ram_value ""
RAM_MODE_RESULT=""; RAM_VALUE_RESULT=""
printf '2
512
' | ask_mode_and_value vpsX ram RAM RAM MB "in MB" is_valid_ram_value >/dev/null
t "limit chosen -> mode saved" 2 "$(pref_get ram_mode 1)"
t "limit chosen -> value saved" 512 "$(pref_get ram_value 0)"
RAM_MODE_RESULT=""; RAM_VALUE_RESULT=""
ask_mode_and_value vpsX ram RAM RAM MB "in MB" is_valid_ram_value <<< $'

' >/dev/null
t "Enter Enter repeats: mode" limited "$RAM_MODE_RESULT"
t "Enter Enter repeats: value" 512 "$RAM_VALUE_RESULT"
ask_mode_and_value vpsX ram RAM RAM MB "in MB" is_valid_ram_value <<< "1" >/dev/null
RAM_MODE_RESULT=""; ask_mode_and_value vpsX ram RAM RAM MB "in MB" is_valid_ram_value <<< "" >/dev/null
t "after choosing unlimited it becomes the default" unlimited "$RAM_MODE_RESULT"
ask_mode_and_value vpsX ram RAM RAM MB "in MB" is_valid_ram_value <<< $'2
5
0
0' >/dev/null && r=bad || r=ok
t "typing 0 backs out" ok "$r"
rm -f "$PREFS_FILE"

# --- wizard: 0 goes back ONE step ---
WZ_LOG=""
wz_a() { WZ_LOG+="a"; return 0; }
wz_b() { WZ_LOG+="b"; [ "${WZ_B_COUNT:-0}" -eq 0 ] && { WZ_B_COUNT=1; return "$WIZARD_BACK"; }; return 0; }
wz_c() { WZ_LOG+="c"; return 0; }
run_wizard wz_a wz_b wz_c
t "back from step 2 returns to step 1 only (a b a b c)" "ababc" "$WZ_LOG"
wz_first_back() { return "$WIZARD_BACK"; }
run_wizard wz_first_back wz_a && r=done || r=left; t "back on the first step leaves the wizard" left "$r"
wz_abort() { return 1; }
run_wizard wz_a wz_abort wz_c; t "an error stops the wizard with its code" 1 "$?"

# --- run_guarded: failure runs the cleanup and reports the reason ---
GUARD_CLEANED=""
guard_cleanup() { GUARD_CLEANED="cleaned:$1"; }
guard_ok() { echo fine; }
guard_fail() { echo "ERROR: disk is full"; return 1; }
out=$(run_guarded "guard_cleanup" guard_ok); t "guard: success runs no cleanup" "" "$GUARD_CLEANED"
run_guarded "guard_cleanup" guard_fail >/dev/null; t "guard: failure runs cleanup with the reason" "cleaned:disk is full" "$GUARD_CLEANED"
t "guard: reason is kept" "disk is full" "$GUARD_REASON"

# --- conflicts: duplicate website route / the server's own SSH port ---
CADDY_CONF_DIR=$(mktemp -d)
printf 'a.example.com {
    reverse_proxy http://10.0.0.5:80
    reverse_proxy /api/* http://10.0.0.5:3000
}
' > "$CADDY_CONF_DIR/vps1.caddy"
proxy_route_exists a.example.com "" >/dev/null && r=conflict || r=free; t "same domain root route is a conflict" conflict "$r"
proxy_route_exists a.example.com "/api" >/dev/null && r=conflict || r=free; t "same folder is a conflict (/api = /api/*)" conflict "$r"
proxy_route_exists a.example.com "/other" >/dev/null && r=conflict || r=free; t "another folder is free" free "$r"
proxy_route_exists b.example.com "" >/dev/null && r=conflict || r=free; t "another domain is free" free "$r"
msg=$(proxy_route_exists a.example.com "/api"); case "$msg" in *CONFLICT*already*linked*) r=ok;; *) r=bad;; esac; t "the conflict message says what is wrong" ok "$r"
rm -rf "$CADDY_CONF_DIR"
port_forward_host_conflict 22 tcp >/dev/null && r=free || r=blocked; t "forwarding port 22 is refused" blocked "$r"
ss() { echo 'LISTEN 0 4096 0.0.0.0:8123 0.0.0.0:* users:(("myserver",pid=5,fd=3))'; }
t "host program on a port is named" myserver "$(host_port_owner 8123 tcp)"
port_forward_host_conflict 8123 tcp >/dev/null; t "a port used by the server asks for confirmation" 2 "$?"
unset -f ss

# --- recovery never touches an operation that is still running ---
if [ -r /proc/$$/stat ]; then
  me_start=$(sed 's/^.*) //' /proc/$$/stat | awk '{print $20}')
  vps_state_owner_alive "$$:$me_start" && r=alive || r=dead; t "owner alive: this running process" alive "$r"
  vps_state_owner_alive "999999:1" && r=alive || r=dead;     t "owner dead: unknown pid" dead "$r"
  vps_state_owner_alive "$$:1" && r=alive || r=dead;         t "owner dead: pid reused (other start time)" dead "$r"
  vps_state_owner_alive "" && r=alive || r=dead;             t "owner dead: empty" dead "$r"
fi

# --- Incus protection is present ---
t "incus: compatibility self-test exists" function "$(type -t incus_compat_check)"
t "incus: pin function exists" function "$(type -t incus_pin)"
t "incus: health check exists" function "$(type -t ensure_incus_alive)"
t "image names resolve" "images:ubuntu/noble" "$(resolve_image_candidates images:ubuntu/noble | head -1)"

# --- Caddy: taking over one domain keeps the other domains of that VPS ---
cf=$(mktemp)
printf 'a.com, b.com {
  reverse_proxy 1.2.3.4:80
}
' > "$cf"
caddy_unlink_domain "$cf" a.com
t "caddy unlink: other domain stays" "b.com {" "$(head -n 1 "$cf")"
caddy_unlink_domain "$cf" b.com
[ -f "$cf" ] && r=kept || r=deleted
t "caddy unlink: file removed when no domain is left" deleted "$r"
rm -f "$cf"

# several site blocks in one file
printf 'a.com {
  reverse_proxy 1.1.1.1:80
}
b.com, c.com {
  reverse_proxy 1.1.1.1:81
}
' > "$cf"
caddy_unlink_domain "$cf" c.com
t "caddy unlink: domain in a later block" "b.com {" "$(sed -n 4p "$cf")"
caddy_unlink_domain "$cf" a.com
t "caddy unlink: first block removed whole" "b.com {" "$(head -n 1 "$cf")"
t "caddy unlink: its body is gone" 0 "$(grep -c '1.1.1.1:80' "$cf")"
rm -f "$cf"

# one json call answers the name-by-ip lookup (fake incus, no server needed)
incus() { echo '[{"name":"v1","config":{"user.vpsforge.ip":"10.0.0.5","user.vpsforge.ssh_port":"9001"}},{"name":"v2","config":{},"state":{"network":{"eth0":{"addresses":[{"family":"inet","address":"10.0.0.6"}]}}}}]'; }
t "inventory: saved ip + port" "v1|10.0.0.5|9001" "$(vps_inventory | head -n 1)"
t "inventory: live ip fallback" "v2|10.0.0.6|" "$(vps_inventory | tail -n 1)"
t "name by ip" v2 "$(get_vps_name_by_ip 10.0.0.6)"
unset -f incus

# old kernels: keep the running one and the newest, list the rest
old=$(printf '%s
' linux-image-7.0.0-1013-oracle linux-modules-7.0.0-1011-oracle linux-modules-7.0.0-1012-oracle linux-modules-extra-6.17.0-1020-oracle linux-modules-7.0.0-1013-oracle bash incus | select_old_kernel_packages 7.0.0-1012-oracle | tr '
' ' ')
t "old kernels selected" "linux-modules-7.0.0-1011-oracle linux-modules-extra-6.17.0-1020-oracle " "$old"
t "no kernels: nothing" "" "$(printf 'bash
' | select_old_kernel_packages 7.0.0-1-oracle)"

# tunnel records (fake incus keeps the metadata in a file)
tunnel_store=$(mktemp)
incus() {
  case "$1 $2" in
    "config get") cat "$tunnel_store";;
    "config set") printf '%s' "$5" > "$tunnel_store";;
    "config unset") : > "$tunnel_store";;
  esac
}
tunnel_record_set v1 8080 3000 8080 "" active
tunnel_record_set v1 9090 4000 "" test.example.com stopped
t "tunnel records: two saved" 2 "$(tunnel_get_records v1 | wc -l)"
t "tunnel records: first one" "8080|3000|8080||active" "$(tunnel_get_records v1 | head -n 1)"
tunnel_record_set v1 8080 3001 8080 "" stopped
t "tunnel records: same port replaces" "8080|3001|8080||stopped" "$(tunnel_get_records v1 | tail -n 1)"
t "tunnel records: still two" 2 "$(tunnel_get_records v1 | wc -l)"
tunnel_record_delete v1 8080
t "tunnel records: delete one" "9090|4000||test.example.com|stopped" "$(tunnel_get_records v1)"
tunnel_record_delete v1 9090
t "tunnel records: none left" 0 "$(tunnel_get_records v1 | wc -l)"
unset -f incus
rm -f "$tunnel_store"

# Windows tunnel block: names are unique per server, nothing is left unreplaced, here-string closer at column 0
t "windows id: server + ports" "1_2_3_4_9001_5789" "$(tunnel_windows_id 1.2.3.4 9001 5789)"
fake_key=$(mktemp); printf -- '-----BEGIN FAKE KEY-----\nABC123\n-----END FAKE KEY-----\n' > "$fake_key"
win_block=$(tunnel_access_script vftun5789 1.2.3.4 9001 5789 3000 "$fake_key")
rm -f "$fake_key"
t "tunnel login name: one per tunnel port" "vftun5789" "$(tunnel_access_user 5789)"
t "windows script: no placeholder left" 0 "$(grep -c '@[A-Z]*@' <<< "$win_block")"
t "windows script: key here-string closed at column 0" 1 "$(grep -c "^'@$" <<< "$win_block")"
t "windows script: toggle here-string closed at column 0" 1 "$(grep -c "^'@ | Set-Content" <<< "$win_block")"
t "windows script: the key is inside" 1 "$(grep -c 'ABC123' <<< "$win_block")"
t "windows script: whole script is one block" "& {" "$(head -n 1 <<< "$win_block")"
t "windows script: no password and no root login" 0 "$(grep -ci 'root@' <<< "$win_block")"
t "windows script: only that tunnel port is forwarded" 1 "$(grep -c -F -- '-R "0.0.0.0:5789:${h}:3000" -p 9001 vftun5789@1.2.3.4' <<< "$win_block" | awk '{ print ($1 >= 1) ? 1 : 0 }')"
t "windows script: checks 127.0.0.1 and ::1 before connecting (not just localhost)" 1 "$(grep -c -F -- '"127.0.0.1", "::1"' <<< "$win_block" | awk '{ print ($1 >= 1) ? 1 : 0 }')"

# every site block of a saved Caddy file is read, not only the first line
caddy_text=$(printf 'a.com, b.com {
  reverse_proxy http://1.2.3.4:80
}
c.com {
  handle /x {
    respond ok
  }
}
')
t "caddy_site_domains: all blocks" "a.com b.com c.com" "$(caddy_site_domains <<< "$caddy_text" | tr '
' ' ' | sed 's/ $//')"

echo "Passed: $pass  Failed: $failn"
[ "$failn" -eq 0 ]
