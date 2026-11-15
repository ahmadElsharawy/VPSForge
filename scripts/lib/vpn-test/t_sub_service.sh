#!/bin/bash
# Check that the test VPN's subscription web server runs.
t_sub_service() { systemctl is-active --quiet "vpsforge-vpnsub-$PORT"; }
