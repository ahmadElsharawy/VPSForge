#!/bin/bash
# VPSForge v1.0.0 — Core constants.

# ── Constants ────────────────────────────────────────────────────────────────

VPS_PREFIX="vps"
VPS_IMAGE="images:ubuntu/24.04"
SSH_PORT_BASE=9000
IP_START=11
ROOT_PASSWORD="root"
MIN_RAM_MB=128
PORT_FORWARD_RULES_FILE="/opt/vpsforge/port-forwards.conf"
BACKUP_DIR="/opt/vpsforge-backups"
UBUNTU_IMAGES_CACHE_FILE="/opt/vpsforge/ubuntu_images_cache.txt"
CADDY_CONF_DIR="/etc/caddy/vpsforge"
MAIN_CADDYFILE="/etc/caddy/Caddyfile"
