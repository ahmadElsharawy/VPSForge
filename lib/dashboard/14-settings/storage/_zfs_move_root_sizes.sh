#!/bin/bash
# Print "<vps> <root disk size>" for every VPS (empty size = no limit), one line each, sorted.
# Used to check that every disk limit is the same before and after a storage move.
_zfs_move_root_sizes() {
  incus list --format json 2>/dev/null | python3 -c '
import json, sys
rows = []
for c in json.load(sys.stdin):
    root = (c.get("expanded_devices") or {}).get("root") or {}
    rows.append("%s %s" % (c["name"], root.get("size", "")))
print("\n".join(sorted(rows)))
'
}
