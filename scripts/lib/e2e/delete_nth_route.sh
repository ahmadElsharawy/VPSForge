#!/bin/bash
# Delete the nth reverse proxy route belonging to the test container.
delete_nth_route() { local line; line=$(list_proxy_routes | awk -F'|' -v v="$T" '$1 == v' | sed -n "${1}p" | awk -F'|' '{print $5}'); delete_proxy_route "$T" "$line"; }
