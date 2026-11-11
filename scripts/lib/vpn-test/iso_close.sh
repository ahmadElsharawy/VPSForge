#!/bin/bash
# Remove temporary firewall rules permitting container-to-container traffic.
iso_close() { while iptables -D FORWARD -s "$CIP" -d "$SIP" -j ACCEPT 2>/dev/null; do :; done; while iptables -D FORWARD -s "$SIP" -d "$CIP" -j ACCEPT 2>/dev/null; do :; done; }
