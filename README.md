# VPSForge v1.0.15
VPSForge is an interactive Terminal Bash Manager for lightweight Ubuntu & Linux containers powered by Incus.

## Main Features

- **Reverse Proxy & Auto-SSL (NEW)**: Built-in Caddy integration to route subdomains directly to containers with automatic HTTPS certificates.
- **VPS Management**: Create, Delete, Start, Stop, Restart, and Reinstall single or multiple VPS containers.
- **Inter-VPS Tenant Isolation**: Automatic L2/L3 firewall isolation between VPS containers. Containers share the internal subnet for WAN access but **cannot ping or connect to each other**.
- **Ubuntu Version Choice**: Select between **Ubuntu 24.04 LTS**, **22.04 LTS**, **20.04 LTS**, or **Ubuntu Minimal** builds on creation.
- **Snapshots & Backup / Restore**: Create instant snapshots, list, restore, export full `.tar.gz` backups, or import backups.
- **Realtime Resource Monitoring**: Displays live Network I/O (`↓Received ↑Sent`) alongside RAM, CPU, and Disk usage directly in the dashboard.
- **Resource Limits**: Configure RAM, CPU, Disk quota, and Network speed per VPS or in bulk.
- **Interactive Port Forwarding**: Effortlessly map host ports to any VPS by selecting its name (e.g. `vps1` or `1`) — no manual IP typing needed!
- **Rule Selection**: View, edit, or delete port forwarding rules interactively by rule number.
- **SSH Management**: Automatic fixed SSH port mapping (`9000 + VPS#`), static internal IP allocation, and 1-click SSH repair.
- **Modular Clean Architecture**: Modularized into 9 clean Bash modules under `lib/`.
- **Host Compatibility Checking**: Automatic validation of kernel modules, cgroups v2, and overlayfs storage pool compatibility.
- **Auto Rollback**: Incomplete VPS creations automatically roll back without leaving residual rules.
- **Persistent Settings**: Reinstalling a VPS preserves its RAM, CPU, Disk, Network, SSH port, and credentials.

## Terminal Dashboard

```text
================================================================
                    VPSForge MANAGER v1.0.0
================================================================
Auto Refresh: ON (10s)
Public IP: 1.2.3.4 | Total RAM: 16384MB | VPS limits: 4096MB | Remaining: 12288MB

NAME       STATUS     RAM                CPU        DISK             NETWORK_IO           INTERNAL_IP      PORT
----------------------------------------------------------------------------------------------------------------
vps1       RUNNING    217MB / 1024MB     1 Core     4.8GB / 40GB     1000M [↓1.2M ↑400K]  10.251.174.11    9001
vps2       RUNNING    222MB / 1024MB     1 Core     4.8GB / 5GB      500M [↓45K ↑12K]     10.251.174.12    9002

1) Add
2) Delete
3) Start
4) Stop
5) Restart
6) Reinstall
7) Edit VPS
8) Details
9) Shell
10) Connection
11) Port Forward
12) Snapshots & Backups
13) Settings
14) Exit
```

## Snapshots & Backups

Create, restore, or export backups via menu `#12`:

```text
================================================================
              SNAPSHOTS & BACKUPS
================================================================

1) Create Snapshot
2) List Snapshots
3) Restore Snapshot
4) Delete Snapshot
5) Export Full Backup (tar.gz)
6) Import Full Backup (tar.gz)
0) Back
```

Or run via CLI:

```bash
vpsforge snapshot vps1
vpsforge backup vps1
```

## Supported OS Distributions

When adding a VPS, you can choose from a wide variety of Linux distributions. We strongly support **Minimal** images for the lowest resource footprint:

**Ubuntu Releases:**
- `1) Ubuntu 24.04 LTS (Noble Numbat - Default)`
- `2) Ubuntu 22.04 LTS (Jammy Jellyfish)`
- `3) Ubuntu 20.04 LTS (Focal Fossa)`
- `4) Ubuntu 24.04 Minimal` *(Highly Recommended for low RAM)*
- `5) Ubuntu 22.04 Minimal` *(Highly Recommended for low RAM)*

**Other Linux Distributions:**
- **Debian** (12 Bookworm / 11 Bullseye / 10 Buster)
- **Alpine Linux** (Extremely lightweight, boots in seconds)
- **AlmaLinux** (9 / 8)
- **Rocky Linux** (9 / 8)
- **Fedora / CentOS Stream**
- **Arch Linux**
- *Plus: Search capability for any other distribution available in the Incus repository!*

## Interactive Port Forwarding

Managing NAT port forwarding is simpler than ever:

```text
================================================================
                  PORT FORWARD
================================================================
Configured Port-Forward Rules:
   1) TCP  0.0.0.0:8080 -> vps1 (10.251.174.11):80
   2) UDP  0.0.0.0:9090 -> vps2 (10.251.174.12):9090

1) Add Rule
2) Edit Rule
3) Delete Rule
4) Delete ALL Rules
5) Active NAT Status
0) Back
```

## Installation

### Quick Install from GitHub

```bash
curl -Ls https://raw.githubusercontent.com/ahmadElsharawy/VPSForge/main/install.sh -o /tmp/vpsforge-install.sh && \
VPSFORGE_REPO_URL=https://github.com/ahmadElsharawy/VPSForge.git bash /tmp/vpsforge-install.sh
```

### Manual Install

Clone or download the repository, then run:

```bash
chmod +x install.sh
sudo ./install.sh
```

## Running VPSForge

```bash
VPSForge
```

Check version:

```bash
vpsforge --version
```
