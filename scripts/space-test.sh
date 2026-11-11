#!/bin/bash
# Disk-space test on a REAL host: do snapshots / backups / deleted VPSs leave
# files that keep eating the server's real disk?   sudo bash scripts/space-test.sh
# Only touches its own test container (name below).
set -uo pipefail
SPACE_TMP=$(mktemp -d)   # private folder for this run's temp files

LIB_DIR="${LIB_DIR:-/opt/vpsforge/lib}"
T="vpsforge-space"
export TERM=dumb
source "$LIB_DIR/load_vpsforge_lib.sh"
load_vpsforge_lib "$LIB_DIR"
VPSFORGE_VERSION="space"
get_network_info || exit 1
get_public_ip
load_settings

IMG=/var/lib/incus/disks/default.img
POOL_DIR=$(get_incus_pool_path)
mkdir -p "$BACKUP_DIR"

host_free_mb() { df -m --output=avail / | tail -1 | tr -d ' '; }
img_mb()       { [ -f "$IMG" ] && du -sm "$IMG" | cut -f1 || echo 0; }
pool_used_mb() { incus query /1.0/storage-pools/default/resources 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin)["space"]["used"]/1048576))' 2>/dev/null || echo 0; }
backups_mb()   { du -sm "$BACKUP_DIR" 2>/dev/null | cut -f1; }
report() {
  printf '%-34s host_free=%6sMB  pool_used=%6sMB  default.img_on_disk=%6sMB  backup_dir=%5sMB\n' \
    "$1" "$(host_free_mb)" "$(pool_used_mb)" "$(img_mb)" "$(backups_mb)"
}

cleanup() {
  incus delete "$T" --force >/dev/null 2>&1 || true
  rm -f "$BACKUP_DIR"/space-test-backup*.tar* 2>/dev/null
  rm -rf "${SPACE_TMP:?}"
}
trap cleanup EXIT
incus delete "$T" --force >/dev/null 2>&1 || true
rm -f "$BACKUP_DIR"/space-test-backup*.tar* 2>/dev/null

echo "== SPACE TEST on $(hostname) =="
report "0. baseline"

num=$(next_num); port=$(vps_fixed_port "$num")
create_vps "$T" "$num" 256 "$port" limited unlimited "" limited 8 unlimited "" "images:ubuntu/24.04" unlimited 0 0 n >"$SPACE_TMP/create.log" 2>&1 || { echo "create failed"; tail -5 "$SPACE_TMP/create.log"; exit 1; }
report "1. VPS created"

incus exec "$T" -- sh -c 'dd if=/dev/urandom of=/root/big1 bs=1M count=800 status=none; sync'
report "2. +800MB data in VPS"
incus snapshot create "$T" s1
incus exec "$T" -- sh -c 'dd if=/dev/urandom of=/root/big2 bs=1M count=400 status=none; rm -f /root/big1; sync'
incus snapshot create "$T" s2
report "3. 2 snapshots (big1 deleted, still in s1)"

incus export "$T" "$BACKUP_DIR/space-test-backup.tar" >/dev/null 2>&1
report "4. full backup exported"
echo "   backup file: $(du -h "$BACKUP_DIR/space-test-backup.tar" | cut -f1)"

# --- Delete the VPS through the real menu (needs a tty -> use script) ---
echo "-- deleting VPS with the real delete menu"
cat > "$SPACE_TMP/del.sh" <<EOS
LIB_DIR=$LIB_DIR; VPSFORGE_VERSION=space
for f in "\$LIB_DIR"/core/*.sh; do [ -f "\$f" ] && source "\$f"; done
while read -r f; do source "\$f"; done < <(find "\$LIB_DIR/core" -mindepth 2 -type f -name '*.sh' | sort)
while read -r f; do source "\$f"; done < <(find "\$LIB_DIR" -type f -name '*.sh' ! -path '*/core/*' | sort)
get_network_info; get_public_ip; load_settings
delete_vps_menu
EOS
( sleep 3; echo "$T"; sleep 2; echo "DELETE"; sleep 25; echo ) | script -qec "bash $SPACE_TMP/del.sh" /dev/null >"$SPACE_TMP/del.out" 2>&1
sleep 2
grep -E "Deleted|WARNING|Cancelled" "$SPACE_TMP/del.out" | head
if incus info "$T" >/dev/null 2>&1; then echo "RESULT: VPS STILL EXISTS"; else echo "RESULT: VPS gone"; fi
report "5. VPS deleted"
echo "   leftover subvolumes of $T: $(btrfs subvolume list "$POOL_DIR" 2>/dev/null | grep -c "$T")"
echo "   leftover backup files for it: $(ls "$BACKUP_DIR" | grep -c space-test-backup)  ($(du -sh "$BACKUP_DIR"/space-test-backup* 2>/dev/null | head -1 | cut -f1))"

echo "-- reclaiming freed space (fstrim on the pool)"
fstrim -v "$POOL_DIR" 2>&1 | sed 's/^/   /'
report "6. after fstrim"

# --- interrupted backup leftovers ---
echo "-- interrupted backup test"
num=$(next_num); port=$(vps_fixed_port "$num")
create_vps "$T" "$num" 256 "$port" limited unlimited "" limited 8 unlimited "" "images:ubuntu/24.04" unlimited 0 0 n >"$SPACE_TMP/create.log" 2>&1
incus exec "$T" -- sh -c 'dd if=/dev/urandom of=/root/big bs=1M count=600 status=none; sync'
mkdir -p "$BACKUP_DIR/.tmp"
( incus export "$T" "$BACKUP_DIR/.tmp/space-test-backup-partial.tar" >/dev/null 2>&1 ) &
epid=$!; sleep 4; pkill -9 -f "incus export $T" 2>/dev/null; kill -9 $epid 2>/dev/null; sleep 1
echo "   partial files in .tmp after kill: $(ls "$BACKUP_DIR/.tmp" 2>/dev/null | grep -c space-test) ($(du -sh "$BACKUP_DIR/.tmp" 2>/dev/null | cut -f1))"
echo "   incus internal backups left: $(incus query "/1.0/instances/$T/backups" 2>/dev/null | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null)"
clean_stale_temp_backups >/dev/null 2>&1
echo "   after clean_stale_temp_backups: $(ls "$BACKUP_DIR/.tmp" 2>/dev/null | grep -c space-test) partial file(s) left"
report "7. after partial-backup cleanup"
echo "== done =="
