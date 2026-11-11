#!/bin/bash
# Verify that the temporary QR code web page contains the vless connection URI.
t_page_link() { curl -fsS -m 5 "http://127.0.0.1:$P2$path" | grep -q 'vless://'; }
