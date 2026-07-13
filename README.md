# VPSForge v1.0.0

VPSForge is an interactive Bash manager for lightweight Ubuntu VPS containers powered by Incus.

This is the first public release of VPSForge. It ships as `v1.0.0` and acts as the clean starting point for the project.

## Main Features

- Create one or multiple VPS containers.
- Delete, Start, Stop, Restart, and Reinstall.
- Edit one VPS, multiple VPS containers, or all selected VPS containers.
- Interactive Shell access.
- SSH connection information and repair tools.
- Resource management for RAM, CPU, Disk, and Network speed.
- Automatic fixed SSH port mapping.
- Static internal IP allocation.
- Multi-VPS dashboard.
- Optional Auto Refresh.
- Update / Change Version support.
- Rollback of incomplete VPS creation.
- Reinstall preserves existing resource and access settings.

## Dashboard

The dashboard displays:

- Name
- Status
- Current RAM usage and RAM limit/available RAM
- CPU cores
- Disk usage and disk quota/available disk
- Network speed limit
- Internal IP
- SSH port

Example:

```text
NAME       STATUS     RAM                  CPU        DISK               NETWORK      INTERNAL_IP        PORT
----------------------------------------------------------------------------------------------------------------
vps1       RUNNING    217MB / 1024MB       1 Core     4.8GB / 40GB       50Mbit       10.251.174.11      9001
vps2       RUNNING    222MB / 1024MB       1 Core     4.8GB / 5GB        500Mbit      10.251.174.12      9002
```

There is no `NO` column.

## VPS Selection

A number always maps directly to the VPS name:

```text
1     -> vps1
6     -> vps6
13    -> vps13
vps6  -> vps6
```

This remains true even if only one VPS exists.

Multiple selections are supported:

```text
1,3,vps6,10
```

This means:

```text
vps1, vps3, vps6, vps10
```

`All` selects all VPSForge containers.

## Enter = All for Details and Connection

For the `Details` and `Connection` menus only, pressing Enter without typing anything automatically selects all VPS containers:

```text
VPS name/number, comma-separated list, or All [Enter = All]:
```

Behavior:

```text
Enter       -> All
all         -> All
1           -> vps1
1,2,5       -> vps1, vps2, vps5
vps3        -> vps3
```

This behavior is intentionally limited to `Details` and `Connection`.

For potentially destructive or state-changing actions such as Delete, Start, Stop, Restart, Reinstall, and Edit, an empty Enter does not automatically mean `All`.

## Resource Management

### RAM

```text
1) Unlimited
2) Set RAM Limit
```

The prompt shows total and available host RAM.

### CPU

```text
1) Unlimited
2) Set CPU Limit
```

The CPU limit cannot exceed the host CPU core count.

### Disk

```text
1) Unlimited
2) Set Disk Limit
```

The prompt shows total and available host disk space.

### Network

```text
1) Unlimited
2) Set Speed Limit
```

Network limits are applied to the VPS `eth0` device.

## Add Multiple VPS Containers

When creating multiple VPS containers:

```text
1) Configure each VPS individually
2) Same resource settings for all
```

The shared-resource option applies RAM, CPU, Disk, and Network settings to all newly created VPS containers.

## Edit VPS

Single VPS editing supports:

```text
0) Back
1) Change RAM
2) Change CPU
3) Change Disk
4) Change Network Speed
5) Change SSH Port
6) Change Username
7) Change Password
```

Bulk Edit supports RAM, CPU, Disk, Network Speed, Username, and Password.

For resource changes across multiple VPS containers, settings can be configured individually or shared across all selected VPS containers.

## Back Button Convention

In submenus, the Back option is always:

```text
0) Back
```

and is displayed first.

The main menu has no Back option and continues to use:

```text
12) Exit
```

## SSH Port Mapping

SSH ports are deterministic:

```text
vps1  -> 9001
vps2  -> 9002
vps13 -> 9013
```

Formula:

```text
SSH Port = 9000 + VPS Number
```

## Reinstall Preservation

Reinstall preserves:

- VPS number/name
- RAM mode and limit
- CPU mode and limit
- Disk mode and quota
- Network mode and speed limit
- Internal IP mapping
- SSH port
- Username
- Password

This applies to a single VPS, multiple selected VPS containers, and `All`.

## Delete Cleanup

When a VPS is deleted, VPSForge removes:

- The Incus container.
- SSH port-forwarding rules.
- Any other NAT / FORWARD rules that reference the VPS IP.
- Nginx site files that reference the VPS IP.

Only files and rules that belong to the deleted VPS are removed.

## Creation Rollback

If VPS creation fails before completion, VPSForge removes the incomplete container and all associated port-forwarding rules instead of leaving a broken VPS behind.

## Incus Device Handling

VPSForge safely creates per-instance overrides for inherited Incus devices when required:

- `root` before applying Disk limits.
- `eth0` before applying static IP or Network limits.

## Main Menu

```text
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
11) Settings
12) Exit
```

## Settings

Settings include:

- Enable / Disable Auto Refresh
- Change Refresh Interval
- Repair Connection
- Update / Change Version

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

## Run

```bash
VPSForge
```

## Version

```bash
vpsforge --version
```

## Official Version

```text
v1.0.0
```


## Release Notes

- Fixed `Details` and `Connection`: pressing Enter now selects `All`.
- `Enter = All` applies only to `Details` and `Connection`.
- Removed the invalid `resolve_vps_selection` call and reused the existing `normalize_selection` logic.
- Confirmed the `details()` function exists.
- Confirmed the dashboard uses safe VPS-list iteration and does not lose later VPS entries.
- Confirmed critical menu and management functions are present.
- Confirmed no `resolve_vps_selection` reference remains.
- VPSForge starts here as `v1.0.0`.
- Waits for the real `eth0` interface instead of treating VPSForge's saved IP metadata as a configured guest address.
- Applies the selected IPv4 address and gateway directly inside the guest without relying on `netplan apply`, then verifies the real address, default route, and DNS servers before SSH setup.
- Replaces the inactive `systemd-resolved` loopback DNS stub with usable resolvers inside minimal container images.
- Bash syntax validation passed successfully.
