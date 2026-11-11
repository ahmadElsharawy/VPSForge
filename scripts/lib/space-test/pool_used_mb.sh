#!/bin/bash
# Used space of the default storage pool in megabytes.
pool_used_mb() { incus query /1.0/storage-pools/default/resources 2>/dev/null | python3 -c 'import sys,json; print(int(json.load(sys.stdin)["space"]["used"]/1048576))' 2>/dev/null || echo 0; }
