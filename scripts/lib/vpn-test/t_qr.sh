#!/bin/bash
# Verify that the generated QR code string has non-trivial length.
t_qr() { test "$(vpn_show_qr "$S" phone | wc -c)" -gt 1000; }
