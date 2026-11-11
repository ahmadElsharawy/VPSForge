#!/bin/bash
# Count active reverse proxy routes configured for the test container.
route_count() { list_proxy_routes | awk -F'|' -v v="$T" '$1 == v' | wc -l; }   # only the test VPS (real VPSs may have routes)
