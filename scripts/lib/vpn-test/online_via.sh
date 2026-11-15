#!/bin/bash
# Test internet connectivity through one local SOCKS5 port of the device VPS (1080 Reality, 1081 HY2, 1082 TLS).
online_via() { in_c "curl -4 -fsS -m 15 --socks5-hostname 127.0.0.1:$1 -o /dev/null https://github.com"; }
