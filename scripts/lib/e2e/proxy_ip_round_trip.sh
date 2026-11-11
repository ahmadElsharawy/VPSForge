#!/bin/bash
# Test updating container IP in Caddy reverse proxy configuration back and forth.
proxy_ip_round_trip() { update_vps_proxy_ip "$T" 10.9.9.9 && grep -q '10.9.9.9' "$conf" && update_vps_proxy_ip "$T" "$ip" && grep -q "$ip" "$conf"; }
