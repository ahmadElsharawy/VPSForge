#!/bin/bash
# Check whether the VPN server container and port are listed.
t_listed() { vpn_all_vps | grep -qx "$S|$PORT"; }
