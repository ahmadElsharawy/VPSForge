#!/bin/bash
# Add a reverse proxy HTTP route for the test container.
add_route() { add_proxy_route "$T" "$ip" "$pxy" "$1" "$2" http; }
