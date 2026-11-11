#!/bin/bash
# Temporarily permit direct traffic between client and VPN test containers.
iso_open()  { iptables -I FORWARD 1 -s "$CIP" -d "$SIP" -j ACCEPT; iptables -I FORWARD 1 -s "$SIP" -d "$CIP" -j ACCEPT; }
