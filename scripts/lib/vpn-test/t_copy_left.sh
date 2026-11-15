#!/bin/bash
# Check whether a page folder of the test VPN is still on disk (it must be deleted when it expires).
t_copy_left() { ls "$VPN_SUB_DIR/$PORT/pages" 2>/dev/null | grep -q .; }
