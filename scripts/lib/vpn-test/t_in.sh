#!/bin/bash
# Check whether iptables allows incoming traffic on the temporary QR web port.
t_in() { iptables -S INPUT | grep -q -- "--dport $P2 -j ACCEPT"; }
