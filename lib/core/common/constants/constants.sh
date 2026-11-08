#!/bin/bash
# VPSForge v1.0.0 — Core constants.

# ── Constants ────────────────────────────────────────────────────────────────

VPS_PREFIX="vps"
VPS_IMAGE="images:ubuntu/24.04"
SSH_PORT_BASE=9000
IP_START=100
ROOT_PASSWORD="root"
MIN_RAM_MB=128
PORT_FORWARD_RULES_FILE="/opt/vpsforge/port-forwards.conf"
BACKUP_DIR="/opt/vpsforge-backups"
IMAGE_CACHE_PREFIX="/opt/vpsforge/images_cache_"
CADDY_CONF_DIR="/etc/caddy/vpsforge"
MAIN_CADDYFILE="/etc/caddy/Caddyfile"

# Where VPSForge records how the host looked BEFORE it touched anything, so
# "vpsforge uninstall" can put the server back exactly as it was.
PRE_INSTALL_DIR="/opt/vpsforge/.pre_install"
# Packages VPSForge may install on the host.
VPSFORGE_PACKAGES="incus iptables iptables-persistent netfilter-persistent curl git python3 zstd pigz psmisc btrfs-progs caddy"
# Incus major version VPSForge is tested with (Ubuntu 24.04 LTS ships 6.0.x).
TESTED_INCUS_MAJOR=6
SWAPFILE_PATH="/swapfile.vpsforge"
