#!/bin/bash
# If Incus is still unpacking/creating <name> in the background (the client was stopped but the
# server keeps working), cancel that operation and wait until it is gone, so the half-made VPS
# cannot appear later. Safe to call when nothing is running.
#   cancel_instance_creation <name>
cancel_instance_creation() {
  local name="${1:?name}" op waited=0
  while [ "$waited" -lt 60 ]; do
    op=$(incus query "/1.0/operations?recursion=1" 2>/dev/null | python3 -c '
import sys, json
name = sys.argv[1]
try:
    data = json.load(sys.stdin)
    ops = data.get("running", []) if isinstance(data, dict) else []
    for o in ops:
        res = json.dumps(o.get("resources", {}))
        if ('"/1.0/instances/' + name + '"') in res and o.get("description", "").lower().startswith("creat"):
            print(o["id"]); break
except Exception:
    pass
' "$name" 2>/dev/null)
    [ -n "$op" ] || return 0
    incus query -X DELETE "/1.0/operations/$op" >/dev/null 2>&1 || true
    sleep 1
    waited=$((waited + 1))
  done
  return 0
}
