#!/bin/bash
# VPN (Xray, VLESS + Reality) settings shared by the VPN functions.
# Xray encrypts with AES-GCM, which modern CPUs (x86 AES-NI, ARM crypto extensions) do in hardware:
# measured 3.5x faster than WireGuard on a 1-CPU ARM server.
VPN_XRAY_VERSION="v26.11.9"           # tested release from github.com/XTLS/Xray-core
VPN_INNER_PORT=8443                   # port Xray listens on inside the VPS (TCP)
VPN_GUEST_DIR="/etc/vpsforge-vpn"     # config, keys, device list inside the VPS
VPN_SNI="www.speedtest.net"           # Reality: the VPN looks like a visit to this HTTPS site (TLS 1.3 + HTTP/2)
VPN_API_PORT=10085                    # Xray statistics API, only on 127.0.0.1 inside the VPS
