#!/bin/bash
# VPN (Xray VLESS + Reality, Xray VLESS + TLS, Hysteria2) settings shared by the VPN functions.
# Xray encrypts with AES-GCM, which modern CPUs (x86 AES-NI, ARM crypto extensions) do in hardware:
# measured 3.5x faster than WireGuard on a 1-CPU ARM server.
VPN_XRAY_VERSION="v26.11.9"           # tested release from github.com/XTLS/Xray-core
VPN_INNER_PORT=8443                   # port Xray listens on inside the VPS (TCP)
VPN_GUEST_DIR="/etc/vpsforge-vpn"     # config, keys, device list inside the VPS
VPN_SNI="www.speedtest.net"           # Reality: the VPN looks like a visit to this HTTPS site (TLS 1.3 + HTTP/2)
VPN_API_PORT=10085                    # Xray statistics API, only on 127.0.0.1 inside the VPS
VPN_TLS_INNER_PORT=18443              # port Xray's VLESS+TLS inbound listens on inside the VPS (TCP)
VPN_HY_INNER_PORT=18444               # port Hysteria2 listens on inside the VPS (UDP)
VPN_TLS_PORT_OFFSET=10000             # public VLESS+TLS port = public VPN port + this (TCP)
VPN_TLS_SNI="www.speedtest.net"                 # VLESS+TLS: name in the self-signed certificate and in the link
VPN_HY_SNI="www.speedtest.net"            # Hysteria2: name in the self-signed certificate and in the link
VPN_HY_MASQUERADE_URL="https://www.bing.com/"   # Hysteria2: what a browser sees when it visits the port
# Hysteria2 public UDP ports, tried in this order for each new VPN (first one free on this server).
# All 17 tested from a mobile network that blocks other UDP ports (8443, 3478 and high ports were blocked there).
VPN_HY_PORTS="443 2053 2083 2087 2096 4443 80 2052 2082 2086 2095 8080 8880 500 4500 1194 5060"
