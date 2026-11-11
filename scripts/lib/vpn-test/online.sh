#!/bin/bash
# Test internet connectivity through the local SOCKS5 proxy in client container.
online() { in_c 'curl -4 -fsS -m 15 --socks5-hostname 127.0.0.1:1080 -o /dev/null https://github.com'; }
