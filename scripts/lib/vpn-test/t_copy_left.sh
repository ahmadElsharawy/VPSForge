#!/bin/bash
# Check for any lingering runtime files from the temporary QR server.
t_copy_left() { ls /run/vpsforge-vpn-* /run/vpsforge-vpnqr-* 2>/dev/null | grep -q .; }
