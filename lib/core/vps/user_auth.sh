#!/bin/bash
# VPSForge v1.0.0 — VPS user/password/port metadata getters and setters.

get_vps_user()     { incus config get "$1" user.vpsforge.username 2>/dev/null || echo root; }
get_vps_password() { incus config get "$1" user.vpsforge.password 2>/dev/null || echo "$ROOT_PASSWORD"; }

set_vps_user()     { incus config set "$1" user.vpsforge.username "$2" 2>/dev/null || true; }
set_vps_password() { incus config set "$1" user.vpsforge.password "$2" 2>/dev/null || true; }

get_vps_saved_port() { incus config get "$1" user.vpsforge.ssh_port 2>/dev/null || true; }
set_vps_saved_port() { incus config set "$1" user.vpsforge.ssh_port "$2" 2>/dev/null || true; }
