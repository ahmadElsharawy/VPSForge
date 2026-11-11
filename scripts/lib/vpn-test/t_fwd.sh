#!/bin/bash
# Check whether iptables forwards the VPN port to the server container.
t_fwd() { iptables -t nat -S PREROUTING | grep -q -- "-p tcp .*--dport $PORT .*$SIP:$PORT"; }
