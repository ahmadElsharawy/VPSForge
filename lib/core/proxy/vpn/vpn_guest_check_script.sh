#!/bin/bash
# Print the script that lives inside the VPS (/etc/vpsforge-vpn/check.sh).
# It reads (and resets) Xray's per-device traffic counters and adds them to usage.txt
# (name|total_bytes|last_active_epoch). Without "collect" it also switches off devices that
# passed their data limit or whose days are over, prints one line per device switched off,
# and applies the new config.
vpn_guest_check_script() {
  cat <<'EOF_CHECK'
#!/bin/sh
D=/etc/vpsforge-vpn
cd "$D" || exit 0
[ -s devices.txt ] || exit 0
touch usage.txt
now=$(date +%s)
/usr/local/bin/xray api statsquery --server="127.0.0.1:${API:-10085}" -pattern "user>>>" -reset 2>/dev/null > .stats || : > .stats
# lines look like:  "name": "user>>>phone>>>traffic>>>downlink",   then   "value": "12345"
awk -v now="$now" -v st=.stats -v newus=usage.txt.new '
  BEGIN {
    while ((getline line < st) > 0) {
      if (line ~ /"name"/) { n = line; sub(/.*user>>>/, "", n); sub(/>>>.*/, "", n) }
      else if (line ~ /"value"/ && n != "") { v = line; gsub(/[^0-9]/, "", v); got[n] += v; n = "" }
    }
  }
  { split($0, u, "|"); total[u[1]] = u[2]; active[u[1]] = u[3]; order[++k] = u[1] }
  END {
    for (i = 1; i <= k; i++) {
      m = order[i]; seen[m] = 1
      a = (got[m] > 0) ? now : active[m]
      print m "|" (total[m] + got[m]) "|" a > newus
    }
    for (m in got) if (!(m in seen)) print m "|" got[m] "|" now > newus
    close(newus)
  }
' usage.txt
if [ -f usage.txt.new ]; then mv -f usage.txt.new usage.txt; fi
rm -f .stats
[ "${1:-}" = "collect" ] && exit 0
awk -F'|' -v now="$now" -v us=usage.txt -v newdev=devices.txt.new '
  BEGIN { while ((getline l < us) > 0) { split(l, u, "|"); used[u[1]] = u[2] } }
  NF >= 2 {
    limit = ($6 == "" ? 0 : $6); ex = ($7 == "" ? 0 : $7); state = ($8 == "" ? "on" : $8)
    if (state == "on" && limit > 0 && used[$1] >= limit * 1073741824) { state = "off-data"; print "OFF " $1 " data" }
    if (state == "on" && ex > 0 && now >= ex) { state = "off-time"; print "OFF " $1 " time" }
    print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" limit "|" ex "|" state > newdev
  }
' devices.txt > .events
mv -f devices.txt.new devices.txt
cat .events
if [ -s .events ]; then rm -f .events; sh "$D/apply.sh"; else rm -f .events; fi
EOF_CHECK
}
