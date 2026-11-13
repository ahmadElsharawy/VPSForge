# VPSForge v3.4.1

<p align="center">
  <img src="https://img.shields.io/badge/Version-v3.4.1-blue?style=for-the-badge&logo=git" alt="Version" />
  <img src="https://img.shields.io/badge/Platform-Ubuntu%2022.04%20|%2024.04-orange?style=for-the-badge&logo=ubuntu" alt="Platform" />
  <img src="https://img.shields.io/badge/Backend-Incus%20System%20Containers-brightgreen?style=for-the-badge&logo=linux" alt="Backend" />
  <img src="https://img.shields.io/badge/Storage-BTRFS%20CoW-red?style=for-the-badge&logo=disk" alt="Storage" />
  <img src="https://img.shields.io/badge/Proxy-Caddy%20Auto--SSL-blueviolet?style=for-the-badge&logo=caddy" alt="Proxy" />
  <img src="https://img.shields.io/badge/Traffic-TC%20%2B%20IPTables-yellow?style=for-the-badge&logo=speedtest" alt="Traffic" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License" />
</p>

> **An Interactive, Enterprise-Grade Hypervisor-like Terminal Manager for lightweight Linux (Ubuntu, Debian, Alpine, etc.) VPS containers powered by Incus.**

VPSForge transforms any standard Ubuntu host into an enterprise-ready, multi-tenant VPS virtualization node. By marrying **Incus** (system containers) with **BTRFS** Copy-on-Write storage, **iptables** NAT rules, **Caddy** auto-SSL reverse proxying, and **Traffic Control (tc)** bandwidth shaping, VPSForge provides the full isolation and features of a commercial hypervisor at near-zero virtualization overhead.

---

## ✨ What's new in v3.4.1

- `vpsforge uninstall` removes the ZFS tools again (zfs-zed was blocking the package removal), keeping the clean-host promise.

## ✨ What's new in v3.4.0

- **Each VPS sees only its own disk:** new servers use ZFS storage, so `df -h` inside a VPS shows its own limit (not the whole server). Existing servers can switch from **Settings → 8) Move VPSs to ZFS storage** (every VPS is stopped and moved safely; limits, IPs and ports are kept).
- Snapshots no longer use up the customer's disk limit; ZFS memory use is capped (1/8 of RAM) for small servers; freed space goes back to the real disk.
- Backing up a VPS whose disk is full now shows a clear message (free some space, then retry) instead of a raw Incus error.
- Port forwards of deleted VPSs are now also removed from the saved list, so they never come back after a reboot.

## ✨ What's new in v3.3.0

- **One VPS type: Isolated, and Docker works in it.** The Full (privileged) type is gone: every VPS is
  unprivileged (root inside is an ordinary host user, uid 1000000), so it is safe to rent, and Docker
  still runs in it. The TYPE column left the dashboard and the create wizard no longer asks for a type.
- **How Docker runs unprivileged:** Ubuntu's runc 1.3 cannot start containers in an unprivileged VPS
  (it reopens /proc files the VPS may not touch). VPSForge now copies crun 1.19.1 and fuse-overlayfs
  (pinned, sha256-checked, downloaded once per server) into each VPS, turns on nesting and /dev/fuse,
  and writes /etc/docker/daemon.json, so however Docker is installed later, it just works. Docker
  itself is not pre-installed, so small servers stay light.
- A VPS made by an older version becomes Isolated when it is repaired or reinstalled.

## ✨ What's new in v3.2.8

- **All eight distros verified; Fedora is marked as needing a strong VPS (2GB+ RAM).** With 256MB its
  package install timed out; with 2GB it creates in about 30 seconds.

## ✨ What's new in v3.2.7

- **Alpine is back in the distro menu.** It was dropped by mistake: BusyBox `ss` lists no sockets, so a
  test wrongly saw no SSH. An Alpine VPS does answer on port 22.

## ✨ What's new in v3.2.6

- **Rocky / Alma / RHEL 10 VPSs are created correctly.** NetworkManager's own DHCP connection beat the
  static one and left eth0 down; VPSForge now disables it, waits for NetworkManager and activates its
  own connection. Verified to survive a restart.

## ✨ What's new in v3.2.5

- Alpine was temporarily removed from the distro menu (restored in v3.2.7).

## ✨ What's new in v3.2.4

- **`vpsforge uninstall` removes its packages again (clean-host promise).** It read the pre-install
  record from a file name the capture step never writes (`packages_installed.txt` vs the actual
  `packages_present.txt`), so on every current install it printed "older VPSForge, none removed"
  and left Incus, Caddy and the rest behind. It now walks VPSForge's own package list, keeps any
  that were already on the server before install, and purges the ones it added.

## ✨ What's new in v3.2.3

- **Fixed a shellcheck parse error in the autostart-on-login setting.** A redirect was written
  inside a `[ ... ]` test (`[ -w /etc/profile.d 2>/dev/null ]`); it worked in Bash but broke the
  project's own `scripts/check.sh --lint` gate. The whole codebase is clean under shellcheck again.

## ✨ What's new in v3.2.2

- **Ctrl-C now cancels a running create/clone/backup at once.** A long step (such as the
  in-container package install) used to swallow the interrupt, so the operation ran to the end
  instead of stopping. `run_guarded` now runs the work in the background and waits on it, so a
  Ctrl-C, closed terminal or kill is acted on immediately: the operation stops and everything it
  had reserved (instance, IP, port, firewall rules) is cleaned up, leaving nothing behind.

## ✨ What's new in v3.2.1

- **Self-healing now clears stale port-forward (DNAT) rules too.** The startup sweep already
  removed FORWARD rules for addresses no VPS owns any more; it now also removes dangling DNAT
  rules in PREROUTING that point to a deleted VPS, so a reused port or IP can never route to the
  wrong VPS. Live VPSs keep every rule untouched.

## ✨ What's new in v3.2.0

- **Choose the VPS type when you create it.** The create wizard now asks:
  `1) Full (privileged)` - Docker works, only for you or people you trust;
  `2) Isolated (unprivileged)` - safe to rent to strangers, Docker does NOT work.
  The type is shown in a new **TYPE** column on the main dashboard. Tested on a real
  server: in an Isolated VPS, root inside is an ordinary host user (uid 1000000), cannot
  mount the host filesystem and cannot reach the host; in a Full VPS root is host root
  (uid 0). The full test suite passes on both types (e2e 90/90 Full and Isolated, VPN 55/55).
- **Clearer disk numbers.** The header shows `VPS STORAGE` (real pool size), and a line under
  it adds up: `Disk = Host OS + VPS storage + Backups + Available`, and splits VPS storage into
  `VPS data + OS images (shared)`. Each VPS row shows its full size (its data plus the OS files
  it shares), so rows can add up to more than VPS storage; the shared images are counted once.
- **No stale firewall rules after deleting a VPS.** An SSH-forward FORWARD rule had taken a few
  shapes across versions, and the old cleanup knew only one, so rules for deleted VPSs piled up
  (and could later accept traffic for a VPS that reuses the IP). Every FORWARD rule to the VPS's
  IP on port 22 is now removed, whatever its shape.

---

## ✨ What's new in v3.1.0

- **Choose the VPN's disguise site (Reality SNI).** Creating a VPN now asks which HTTPS site the VPN looks like to anyone watching the network (default `www.speedtest.net`, the last answer is offered next time). VPSForge checks that the site answers with TLS 1.3 + HTTP/2 before using it. The SNI is saved per VPN, so VPNs made earlier keep working unchanged. A device link carries the SNI: a VPN with another SNI needs new links. Tested: `www.microsoft.com` 55/55 (real connection through the VPN), the wizard with `www.apple.com`.

---

## ✨ What's new in v3.0.6

- **Dashboard back to box-drawing lines (`│ ─ ┼`).** The VT100 line drawing of v3.0.3 is printed as letters (`qqqx`) by some terminals, so it was removed.

---

## ✨ What's new in v3.0.5

- **The weekly tidy removes every old kernel package:** the shared header and tool packages that some clouds use (for example `linux-oracle-6.17-headers-6.17.0-1011`) were missed and kept about 150MB each. Tested on Oracle: after a reboot into the new kernel, the tidy removed all old kernel packages.

---

## ✨ What's new in v3.0.4

- **VPS disk limits are really enforced again.** Deleting a VPS, image or snapshot can make the kernel mark btrfs's quota data "inconsistent" (kernel log: `qgroup marked inconsistent`); while that mark is set **no disk limit works** (a VPS limited to 3GB could write 4.5GB) and every VPS shows a tiny usage. VPSForge now detects the mark and rescans the quotas by itself: after every delete, before a disk limit is set, when the dashboard opens and in the weekly tidy. Tested: on a server with the mark set, a 3GB VPS was stopped at 3GB (`Disk quota exceeded`).
- **HOST OS size is exact:** the ~5% that ext4 keeps for root is no longer counted as used by the OS.

---

## ✨ What's new in v3.0.3

- Dashboard drawn with VT100 line drawing (removed again in v3.0.6).
- **VPS disk usage is real:** without btrfs quotas Incus reports a tiny placeholder (16 KiB), which showed as `0.0GB`; such values are now ignored and the VPS folder is measured instead.

---

## ✨ What's new in v3.0.2

- **Auto-refresh leaves no leftovers:** every redraw clears the rest of each line, so pieces of the previous frame no longer stay on the screen.

---

## ✨ What's new in v3.0.1

- **Dashboard borders drawn with box-drawing lines** (`│ ─ ┼`): they stay straight in terminals whose font draws `-` narrower than letters (plain `| - +` is kept when the terminal cannot show UTF-8).

---

## ✨ What's new in v3.0.0

v3.0.0 gathers every change since v2.1.26 (v2.1.27 - v2.1.35): a full code review of every file, clean code (one function per file), safer uninstall, private backups and many fixes, all tested on two real servers.


- **Snapshot restore keeps the current IP and SSH port.** Restoring a snapshot taken before an IP change no longer brings back the old address (which another VPS may use now).
- **Domains with several names** (`a.com, www.a.com { ... }`) are read and edited correctly; comments and a last line without a newline no longer confuse the Caddy config reader.
- **Tunnels of stopped VPSs** and **disabled port forwards** are respected on restore and import; importing a backup with domains installs Caddy first when the host has none.
- **Safer uninstall:** other Incus projects, storage pools and containers that VPSForge did not make are kept; the packages and iptables rules go back to the record taken before the install.
- **Private backups:** backup folders are `700` and backup files `600`.
- **Cloned VPSs** get their own identity (no copied VPN), **reinstall** recovery after an interruption is safer, and a stopped or interrupted backup export no longer leaves Incus's internal backup behind.
- **Clean code:** one function per file everywhere (also the test scripts), long functions split by job.
- A failed reinstall of a private VPS no longer opens SSH to the internet; restoring port forwards removes stale old rules; editing a tunnel keeps its own ports.
- Many smaller fixes from a full review (port-forward listing, IP collisions, image list on ARM, the add wizard's `0 = Back`, the VPN overview says TCP).

---

## ✨ What's new in v2.1.26

- **README brought up to date** (no code change): the dashboard map and the file directory now include the tunnels and the VPN, the CLI reference shows `port-forward edit`, the Windows tunnel chapter explains how the site address is chosen, and a new chapter, [11. What was tested and the known limits](#11--what-was-tested-and-the-known-limits), says exactly what has been tried on a real server and what has not.

---

## ✨ What's new in v2.1.25

- **Windows tunnels no longer fail when your site listens on one address only.** The setup script used to forward visitors to `localhost`, which Windows may turn into `::1` (IPv6) while your site listens on `127.0.0.1` only (or the other way round): visitors got nothing. Before every connection the script now checks which of `127.0.0.1` and `::1` your site really answers on and uses that one (it falls back to `localhost` if the site is not running yet). Existing tunnels keep the old script: delete the tunnel and add it again to get the fix. Tested on Windows with Windows OpenSSH against a real tunnel.

---

## ✨ What's new in v2.1.24

- **VPN** (menu 12 > 5): turn any VPS into a fast VPN with **Xray (VLESS + Reality)**. Your phone or PC goes online with the VPS's IP and speed, and the traffic looks like a normal HTTPS visit to `www.speedtest.net`, so it is hard to block or slow down. Each device gets its own **data limit (GB) and number of days** (or unlimited) and is switched off by itself when one runs out (checked every 5 minutes); renew it any time. Share a device with a **QR page** (QR code + "Copy link", works for 10 minutes) or its `vless://` link; the app (v2rayNG, Streisand, V2Box, v2rayN) shows the name `<server IP>-<VPS>-<days>-<GB>` by itself. Measured on a 1-CPU ARM server: about 3x faster than WireGuard (the CPU is the limit; more CPUs = more speed). Tested by `scripts/vpn-test.sh` on a real host.
- **Every menu option checked end to end on a real server** (and its tests brought up to date): `port-forward edit` really edits a rule (the old one comes back if the new one fails); VPS names follow exactly what Incus accepts and are checked as you type them; error messages in Port Forward stay on screen; Settings prompts default to the current values; `vpsforge ram` checks and verifies.
- **Changing a VPS's internal IP really changes it.** The card used to keep its old address on a running VPS (a hidden setting was removed while it ran); now the new address is checked on the card and inside the VPS, and a refused change leaves everything as it was. Swapping two VPSs' IPs goes through a spare address, and two VPSs sharing one IP are fixed for real (the one that truly holds it keeps it).
- **Safer updates.** Two updates can no longer run at the same time (a lock), and the installed version is recorded only after the new code is verified, so a rolled-back update never claims the new version.
- **Safer storage migration and uninstall.** The move to BTRFS never touches containers VPSForge did not create and finishes by itself if it was stopped half-way. `vpsforge uninstall` keeps the storage pool, bridge and images of an Incus that was on the server before VPSForge.
- **Reinstall recovery keeps the website.** If a reinstall is killed half-way, the restored VPS keeps its port forwards and its Caddy file.
- **Smaller fixes:** removing the last route of a second domain no longer leaves an empty block in Caddy; deleting a tunnel of a stopped VPS removes its login when the VPS runs again; a real 1 Mbit speed limit survives the monthly quota reset; free disk space no longer counts what a VPS already used twice; name-based SSH ports never fall on a numbered VPS's port and a port the server itself uses is refused; the VPS list and the forward list ask Incus once instead of once per VPS.
- **On purpose:** VPSs stay *privileged* so Docker, WireGuard and the VPN work inside them. Give a VPS only to people you trust with root on it.
- **Tested on a real Oracle ARM server:** `scripts/e2e.sh`, `scripts/ui-test.py` (every menu, no safe mode), `scripts/vpn-test.sh` and `scripts/space-test.sh`.

---

## ✨ What's new in v2.1

- **Sites from MY computer** (menu 12 > 4): open a site that runs on your own PC to the internet through a VPS, **without opening any port on your router**. Your PC connects *out* to the VPS and visitors come in through the same connection. Add several tunnels per VPS, then list, start, stop, edit or delete each one (or all of them) from one table. A port tunnel appears in Port Forward (menu 11) by itself and disappears when you stop it. See [6.6b](#66b-sites-from-my-computer-reverse-tunnels-menu-12--4).
- **One line on Windows.** The menu shows a single line to paste in PowerShell plus a password. It downloads the setup from the VPS and installs it: an SSH key, a hidden task that starts at every login and reconnects by itself, and a desktop icon that opens a small window showing ON or OFF with **On / Off / Delete** buttons (Delete removes the tunnel from that computer and its icon). Linux and macOS get a one-line loop too.
- **Safe to give to a friend.** Each tunnel gets its own limited login (`vftun<port>`): it can open that one port and nothing else (no shell, no other forwards, no unix sockets, no password use elsewhere). "New key" takes access back from anyone; deleting one tunnel leaves the others untouched.
- **The main server stays clean by itself.** A weekly tidy (cron) trims the system journal (200 MB cap), removes old kernels, clears the apt cache and deletes damaged or half-written backups. Deleting a VPS returns its space to the real disk, and `vpsforge uninstall` also restores the firewall rules it added.
- **Damaged backups and snapshots never stay.** Every export and snapshot is verified right after it is made; a bad one is deleted at once with the reason shown. Importing a backup over an existing VPS keeps the old one aside until the new one is complete.
- **Fewer Incus calls** (one `incus list --format json` instead of one call per VPS), so menus stay fast on weak servers. Caddy domain removal handles every site block of a file, and port-forward rules are validated (protocol, IPv4, port range, reserved ports 22/80/443).
- **Backups, copies and snapshots keep tunnels, ports and domains right.** Importing a backup under a new name gives it a new internal IP and SSH port, moves its forwards and Caddy routes to them, checks every domain block for conflicts, keeps the saved login, and marks each tunnel *active* only if its public side really came back (otherwise *stopped*). A copy gets a new tunnel key. Cloning never copies the source's tunnels. A failed or cancelled import can no longer remove the original VPS's SSH port or forwards. A backup file without its `.info` is read directly (its settings live inside the archive), and an import stopped while changing Caddy puts every Caddy file back.
- **A full code review and the fixes from it.** Six Opus reviewers and a Gemini review read the whole project; the confirmed problems were fixed and tested on a real server. Highlights: a VPS can no longer reach another VPS's SSH port over the bridge; a failed reinstall keeps the original's domains, forwards, traffic quota and SSH choice; the owner's own forwards to port 22 survive; disabled forwards stay disabled at every start; traffic quotas keep a monthly running total that a VPS restart cannot reset; deleting snapshots and changing the OS of selected VPSs now ask first (`REINSTALL`); a port-forward edit is validated before the old rule is removed; a new VPS never takes an address another VPS holds; the weekly tidy no longer runs the full startup. Every forwarded port (not only SSH) is now accepted only for traffic that comes from outside the bridge, so a VPS cannot reach another VPS's forwarded ports either; older unrestricted rules are removed automatically at the next start.
- **More fixes from a second independent review.** Removing one domain no longer deletes the VPS's other domains; forwards bound to the server IP and IPv6 traffic are isolated between VPSs too; a clone of a VPS without public SSH stays without it; a new login gets the VPS password; the backup export check allows for Incus staging the tarball; the weekly tidy leaves files younger than an hour alone; an interrupted import is cancelled in Incus; a failed replace-import brings the original's domains back live; uninstall works without Incus and keeps other Incus projects, pools and volumes; the host's IPv6 router advertisements are no longer disturbed.
- **Reviewed and tested.** Offline tests (`scripts/test.sh`, 99 checks) and real-server UI tests cover the tunnel feature, including "add two tunnels, delete one, the other keeps working".

---

## ✨ What's new in v2.0.0

- **Nothing is ever left half-done.** Creating, importing, cloning, backing up, snapshotting and reinstalling are guarded: if anything fails or is stopped (error, Ctrl-C, closed terminal, even `kill -9` or a power cut), the half-made VPS is removed completely (disk, RAM limits, IP, SSH port, firewall rules, proxy config) and you are told why. A reinstall keeps the original aside and puts it back if the new one cannot be finished.
- **Clean server.** Deleting a VPS removes its snapshots and firewall rules, offers to delete its backups, and returns the freed space to the real disk. `vpsforge uninstall` puts the whole server back as it was before VPSForge (packages included).
- **The last answer is the default** in every prompt (RAM/CPU/disk/network/traffic, OS, ports, domain, protocol, selection...), so *Enter, Enter, Enter* repeats what you did before. **`0` goes back one step**, not to the start.
- **One edit menu** for one, several or all VPSs. **More operating systems**: Ubuntu, Debian, Alpine (about 10MB RAM, ideal for weak servers), Rocky, Alma, Fedora, Arch, CentOS.
- **Domains made simple** (menu 12, Domains & Reverse Proxy): add a domain in 5 guided steps, see all domains in one list, test or remove them; Caddy changes are validated and rolled back if invalid.
- **Clone a VPS** (menu 13, option 13): an instant exact copy to experiment on.
- **Protected against Incus updates**: the tested Incus is paused from updating, `vpsforge selftest` checks that every Incus command VPSForge needs still works, and Incus is repaired automatically if it breaks or disappears.
- **Faster and lighter**: cached public IP, one-time setup, BTRFS pool sized to the server (with a directory-pool fallback), swap for very small servers, backups compressed with zstd.
- **Every function is its own file**, grouped in topic folders, with offline tests (`scripts/test.sh`), real-server tests (`scripts/e2e.sh`, `scripts/ui-test.py`) and a loader (`lib/load_vpsforge_lib.sh`).

---

## 📑 Table of Contents

1. [🚀 Quick Installation & Setup](#1--quick-installation--setup)
2. [🖥️ System Architecture Overview](#2-️-system-architecture-overview)
3. [🌐 Network Topology & Inter-VPS Isolation](#3--network-topology--inter-vps-isolation)
4. [🧭 Main Dashboard & Navigation Map](#4--main-dashboard--navigation-map)
5. [🔄 Container Lifecycle & Multi-Selection Engine](#5--container-lifecycle--multi-selection-engine)
6. [🛠️ Feature-by-Feature Deep Dive with Flowcharts](#6-️-feature-by-feature-deep-dive-with-flowcharts)
   - [6.1 VPS Creation Wizard (Menu 1)](#61-vps-creation-wizard-menu-1)
   - [6.2 VPS Deletion & Resource Cleanup (Menu 2)](#62-vps-deletion--resource-cleanup-menu-2)
   - [6.3 Container Reinstall & State Preservation (Menu 6)](#63-container-reinstall--state-preservation-menu-6)
   - [6.4 Resource Tuning & Live Modifications (Menu 7)](#64-resource-tuning--live-modifications-menu-7)
   - [6.5 Port Forwarding & Conflict Detection (Menu 11)](#65-port-forwarding--conflict-detection-menu-11)
   - [6.6 Domain Reverse Proxy & Auto-SSL via Caddy (Menu 12)](#66-domain-reverse-proxy--auto-ssl-via-caddy-menu-12)
   - [6.6b Sites from MY computer: reverse tunnels (Menu 12 > 4)](#66b-sites-from-my-computer-reverse-tunnels-menu-12--4)
   - [6.6c VPN: Xray VLESS + Reality (Menu 12 > 5)](#66c-vpn-xray-vless--reality-menu-12--5)
   - [6.7 Snapshots & Compressed Backups (Menu 13)](#67-snapshots--compressed-backups-menu-13)
7. [⚙️ Engineering Secrets & Core Algorithms](#7-️-engineering-secrets--core-algorithms)
   - [7.1 BTRFS Copy-on-Write & Instant Snapshots](#71-btrfs-copy-on-write--instant-snapshots)
   - [7.2 Automated Live Storage Migration](#72-automated-live-storage-migration)
   - [7.3 Network Traffic Quota Daemon & TC Throttling](#73-network-traffic-quota-daemon--tc-throttling)
   - [7.4 SSH 1-Click Repair & Native LXC Container Architecture](#74-ssh-1-click-repair--native-lxc-container-architecture)
   - [7.5 In-Place Auto-Update & Version Switcher](#75-in-place-auto-update--version-switcher)
8. [📂 Project File Directory & Module Structure](#8--project-file-directory--module-structure)
9. [🧠 AI / Developer System Reconstruction Guide](#9--ai--developer-system-reconstruction-guide)
10. [💻 CLI Command Reference](#10--cli-command-reference)
11. [✅ What was tested and the known limits](#11--what-was-tested-and-the-known-limits)

---

## 1. 🚀 Quick Installation & Setup

```mermaid
flowchart TD
    Start["User runs curl install.sh"] --> CheckRoot{"Is Root / Sudo?"}
    CheckRoot -->|No| FailExit["Abort with error"]
    CheckRoot -->|Yes| InstallPkgs["Install packages: curl, git, python3, btrfs-progs, iptables"]
    InstallPkgs --> CloneRepo["Clone VPSForge repo into /opt/vpsforge"]
    CloneRepo --> CreateSymlinks["Create CLI symlinks: /usr/local/bin/vpsforge & vpsforge-update"]
    CreateSymlinks --> LaunchSetup["Execute ensure_setup.sh"]
    LaunchSetup --> KernelCheck["Run compat_check.sh: FUSE, cgroups v2, OverlayFS, IP Forwarding"]
    KernelCheck --> IncusInit["Verify / Initialize Incus Daemon & incusbr0 Bridge"]
    IncusInit --> BtrfsPool["Setup / Verify BTRFS Default Storage Pool (25GiB default.img)"]
    BtrfsPool --> ProfileRoot["Bind default storage pool to default profile root disk"]
    ProfileRoot --> Ready["Open Interactive VPSForge Terminal Dashboard"]
```

### One-Line Quick Install (Recommended)
```bash
curl -sSL https://raw.githubusercontent.com/ahmadElsharawy/VPSForge/main/install.sh | sudo bash
```

### Manual Installation
```bash
git clone https://github.com/ahmadElsharawy/VPSForge.git
cd VPSForge
sudo bash install.sh
```

### Version Update & Rollback
```bash
vpsforge update          # Upgrade to latest release / origin/main
vpsforge update v1.0.1   # Switch to specific release tag
vpsforge update --list   # List all available releases
vpsforge update --check  # Check update and synchronization status
vpsforge-update          # CLI alias wrapper
```

---

## 2. 🖥️ System Architecture Overview

VPSForge operates as a high-performance terminal control plane sitting on top of Linux kernel features and system daemons:

```mermaid
graph TD
    subgraph UI_Layer["Terminal Interface Layer"]
        CLI["CLI Commands (vpsforge start, stop, list, etc.)"]
        Dash["Interactive Terminal Dashboard (ncurses-style)"]
        Helper["Python Performance Aggregator (dashboard_helper.py)"]
    end

    subgraph Core_Control_Plane["VPSForge Core Control Plane (/opt/vpsforge/lib)"]
        Lifecycle["VPS Lifecycle Manager (create, delete, reinstall)"]
        Firewall["Firewall & NAT Manager (iptables rules & persistence)"]
        ProxyMgr["Reverse Proxy Manager (Caddyfile generator)"]
        QuotaMgr["Traffic Quota & Rate Limiter (tc & cron)"]
        SnapMgr["Backup & Snapshot Manager (BTRFS CoW & tar.gz)"]
    end

    subgraph Linux_Kernel_Daemons["Underlying Linux Daemons & Kernel Subsystems"]
        Incus["Incus Container Daemon (lxc/incus)"]
        Cgroup["Linux cgroups v2 (RAM & CPU throttling)"]
        TC["Linux Traffic Control tc (Bandwidth shaping)"]
        IPT["Linux netfilter / iptables (Port forwarding & accounting)"]
        BTRFS["BTRFS Filesystem (Copy-on-Write instant snapshots)"]
        Caddy["Caddy Web Server (Automated Let's Encrypt SSL)"]
    end

    Dash --> Core_Control_Plane
    CLI --> Core_Control_Plane
    Helper --> Incus
    Core_Control_Plane --> Linux_Kernel_Daemons
```

---

## 3. 🌐 Network Topology & Inter-VPS Isolation

Every container is assigned a static internal IPv4 address on the isolated subnet `10.135.30.0/24` with dedicated NAT routing for SSH (`9000 + N`) and custom services:

```mermaid
graph TD
    subgraph Host_Node["Host Server (Public IP: 203.0.113.10)"]
        HostNIC["Physical Interface (eth0 / ens3)"] --> IPTables["Host iptables NAT & Filtering Engine"]
        
        IPTables -->|Port 9001| DNAT_SSH1["DNAT: 10.135.30.101:22"]
        IPTables -->|Port 9002| DNAT_SSH2["DNAT: 10.135.30.102:22"]
        IPTables -->|Port 80/443| CaddyEngine["Caddy Reverse Proxy"]
        IPTables -->|Port 8080| DNAT_CUSTOM["DNAT: 10.135.30.102:80"]

        CaddyEngine --> Bridge["Incus Virtual Bridge: incusbr0 (10.135.30.1/24)"]
        DNAT_SSH1 --> Bridge
        DNAT_SSH2 --> Bridge
        DNAT_CUSTOM --> Bridge

        Bridge -->|veth_vps1| GUEST1["VPS 1: vps1 (10.135.30.101)"]
        Bridge -->|veth_vps2| GUEST2["VPS 2: vps2 (10.135.30.102)"]

        subgraph Firewall_Isolation["L2/L3 Inter-VPS Firewall"]
            GUEST1 <-.->|Blocked Inter-Container Traffic| GUEST2
        end
    end
```

---

## 4. 🧭 Main Dashboard & Navigation Map

```mermaid
graph LR
    Main["VPSFORGE MAIN DASHBOARD"] --> M1["1) Add VPS"]
    Main --> M2["2) Delete VPS"]
    Main --> M3["3) Start VPS"]
    Main --> M4["4) Stop VPS"]
    Main --> M5["5) Restart VPS"]
    Main --> M6["6) Reinstall VPS"]
    Main --> M7["7) Edit VPS"]
    Main --> M8["8) Details"]
    Main --> M9["9) Shell Attach"]
    Main --> M10["10) Connection Info"]
    Main --> M11["11) Port Forwarding"]
    Main --> M12["12) Domains & Reverse Proxy"]
    Main --> M13["13) Snapshots & Backups"]
    Main --> M14["14) Settings & Updates"]
    Main --> M15["0) Exit"]

    M12 --> D1["Add a domain / My domains"]
    M12 --> D2["Cloudflare real visitor IP"]
    M12 --> D3["Sites from MY computer (reverse tunnels)"]
    M12 --> D4["VPN (Xray VLESS + Reality)"]

    M7 --> E1["RAM / CPU / Disk Limits"]
    M7 --> E2["Bandwidth & Traffic Quota"]
    M7 --> E3["SSH Port / User / Password"]
    M7 --> E4["Swap IP/Port / Rename"]
    M7 --> E5["Reinstall & Change OS"]

    M13 --> S1["Instant Snapshot (Create/Restore/Delete)"]
    M13 --> S2["Full Backup (Export/Import/Inspect .tar.gz)"]
```

---

## 5. 🔄 Container Lifecycle & Multi-Selection Engine

### Container Lifecycle State Machine
```mermaid
stateDiagram-v2
    [*] --> Stopped : Created / Initialized
    Stopped --> Starting : vpsforge start
    Starting --> Running : Booted & Static IP Bound
    Running --> Stopping : vpsforge stop
    Stopping --> Stopped : Clean Shutdown
    Running --> Rebooting : vpsforge restart
    Rebooting --> Running : Restarted
    Running --> Throttled : Traffic Quota Exceeded (tc 1Mbit)
    Throttled --> Running : Limit Raised / Reset
    Running --> Reinstalling : vpsforge reinstall
    Reinstalling --> Running : Rootfs Wiped & Config Restored
    Stopped --> Deleted : vpsforge delete
    Deleted --> [*]
```

### Universal Selection Parser Flowchart
Any command or menu supports multi-input strings (e.g., `1-3,5,vps7,A`):

```mermaid
flowchart TD
    Input["Raw User Input (e.g. 1-3,5,vps7,A)"] --> CheckAll{"Is input == 'A' or 'all'?"}
    CheckAll -->|Yes| AllTargets["Select all available containers"]
    CheckAll -->|No| SplitTokens["Split by comma ',' or space ' '"]
    SplitTokens --> ProcessToken["For each token:"]
    
    ProcessToken --> CheckRange{"Contains dash '-' (e.g. 1-3)?"}
    CheckRange -->|Yes| ExpandRange["Expand numeric range: 1, 2, 3"]
    CheckRange -->|No| CheckNumeric{"Is token an integer ID?"}
    
    CheckNumeric -->|Yes| MapNum["Lookup container by index"]
    CheckNumeric -->|No| MapName["Lookup container by name"]
    
    ExpandRange --> Deduplicate["Deduplicate target list"]
    MapNum --> Deduplicate
    MapName --> Deduplicate
    Deduplicate --> FinalExecution["Execute batch operation on resolved targets"]
```

---

## 6. 🛠️ Feature-by-Feature Deep Dive with Flowcharts

### 6.1 VPS Creation Wizard (Menu 1)
```mermaid
flowchart TD
    StartCreate["Start VPS Creation"] --> PromptCount["Enter number of containers to create (Bulk support)"]
    PromptCount --> LoopVPS["For each container:"]
    LoopVPS --> AutoName["Generate unique name: vps1, vps2, ..."]
    AutoName --> FetchImages["Query Incus remote images:ubuntu and parse aliases"]
    FetchImages --> SelectImage["Choose OS: 24.04 (noble), 22.04 (jammy), cloud-init, etc."]
    SelectImage --> ResourcePrompt["Specify RAM (MB), CPU Cores, Disk (GB), Network Speed (Mbps)"]
    ResourcePrompt --> QuotaPrompt["Specify Download/Upload Data Quota (GB)"]
    QuotaPrompt --> UserPrompt["Specify Default Username & Password (or generate secure random)"]
    UserPrompt --> IncusLaunch["Execute: incus launch image container --no-profiles"]
    IncusLaunch --> SetCgroups["Apply RAM, CPU, Disk limits via incus config"]
    SetCgroups --> InjectNetplan["Write static Netplan YAML to guest rootfs"]
    InjectNetplan --> ConfigureSSH["Inject SSH keys and root password"]
    ConfigureSSH --> AddIPTables["Create iptables NAT rules for SSH port (9000+N)"]
    AddIPTables --> AddQuotaRules["Add iptables FORWARD quota tracking rules"]
    AddQuotaRules --> BootVerify["Boot container & verify ping/SSH connectivity"]
    BootVerify --> SuccessSummary["Print credentials summary table"]
```

---

### 6.2 VPS Deletion & Resource Cleanup (Menu 2)
```mermaid
flowchart TD
    StartDel["Select Container(s) to Delete"] --> Confirm["Confirm Deletion [y/N]"]
    Confirm -->|No| Abort["Cancel Operation"]
    Confirm -->|Yes| StopGuest["Force Stop Container: incus stop name --force"]
    StopGuest --> DelSnapshots["Delete all container BTRFS snapshots"]
    DelSnapshots --> ReleaseNAT["Delete Host iptables PREROUTING & FORWARD NAT rules"]
    ReleaseNAT --> ReleaseQuota["Delete iptables FORWARD quota tracking rules"]
    ReleaseQuota --> DelCaddy["Remove /etc/caddy/vpsforge/domain.conf & Reload Caddy"]
    DelCaddy --> RemoveIncus["Delete Instance from Incus storage pool"]
    RemoveIncus --> ReclaimStorage["BTRFS CoW space reclaimed immediately"]
```

---

### 6.3 Container Reinstall & State Preservation (Menu 6)
Reinstall wipes the OS completely while guaranteeing zero metadata loss:

```mermaid
flowchart TD
    ReinstallReq["Reinstall VPS Requested"] --> DumpState["Extract metadata: IP, SSH Port, RAM, CPU, Disk, Quota, Pass, SSH Keys"]
    DumpState --> DestroyOld["Destroy existing rootfs: incus delete name --force"]
    DestroyOld --> ProvisionClean["Launch fresh container from selected OS image"]
    ProvisionClean --> RestoreLimits["Re-apply saved RAM, CPU cores, Disk, Network speed"]
    RestoreLimits --> ReapplyNet["Write saved static IP and Gateway into guest rootfs"]
    ReapplyNet --> RestoreAuth["Re-inject saved root password and /root/.ssh/authorized_keys"]
    RestoreAuth --> RestoreNAT["Rebuild host iptables NAT rules"]
    RestoreNAT --> ReadyReinstall["VPS online with fresh OS and identical connection parameters"]
```

---

### 6.4 Resource Tuning & Live Modifications (Menu 7)
Modify any hardware resource without reinstalling:

```mermaid
flowchart LR
    EditMenu["Edit VPS Submenu"] --> RAM["1. RAM Limit: incus config set limits.memory"]
    EditMenu --> CPU["2. CPU Cores: incus config set limits.cpu"]
    EditMenu --> DISK["3. Disk Quota: incus config device set root size"]
    EditMenu --> SPEED["4. Network Speed: incus config device set eth0 limits.max"]
    EditMenu --> QUOTA["5. Traffic Data Quotas (Rx/Tx GB)"]
    EditMenu --> PORT["6. Change SSH Port (Updates iptables NAT)"]
    EditMenu --> CRED["7/8. Change Username / Password inside guest"]
    EditMenu --> SWAP["11. Swap IP and Port between 2 containers"]
```

---

### 6.5 Port Forwarding & Conflict Detection (Menu 11)
```mermaid
sequenceDiagram
    actor Admin as Administrator
    participant Dashboard as VPSForge Dashboard
    participant Validator as Port Conflict Validator
    participant HostIPT as Host iptables (NAT)
    participant Guest as Container (vps1)

    Admin->>Dashboard: Add Port Forward (Host: 8080 -> vps1: 80, TCP)
    Dashboard->>Validator: Check if host port 8080 is in use
    alt Port in use
        Validator-->>Dashboard: Conflict Error (Port already bound)
        Dashboard-->>Admin: Display error and abort
    else Port available
        Validator-->>Dashboard: Port valid & clear
        Dashboard->>HostIPT: iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to 10.135.30.101:80
        Dashboard->>HostIPT: iptables -A FORWARD -p tcp -d 10.135.30.101 --dport 80 -j ACCEPT
        Dashboard->>Dashboard: Save rule to /opt/vpsforge/port-forwards.conf
        Dashboard-->>Admin: Port forward active & persistent across reboots!
    end
```

---

### 6.6 Domain Reverse Proxy & Auto-SSL via Caddy (Menu 12)
```mermaid
flowchart TD
    ClientReq["External Client HTTPS Request: https://app.example.com"] --> DNS["DNS A-Record points to Host Public IP"]
    DNS --> CaddyPort["Caddy listening on Ports 80 & 443"]
    CaddyPort --> AutoSSL{"Has valid SSL Cert?"}
    AutoSSL -->|No| ACME["Request Free SSL from Let's Encrypt / ZeroSSL (Automatic)"]
    ACME --> InstallCert["Install & Cache Certificate in memory"]
    AutoSSL -->|Yes| ReadCaddyfile["Read /etc/caddy/vpsforge/app.example.com.conf"]
    InstallCert --> ReadCaddyfile
    ReadCaddyfile --> TrustCF["Trust Cloudflare Proxy IPs & Extract Real Client IP"]
    TrustCF --> ProxyPass["Reverse Proxy to Guest: 10.135.30.101:3000"]
    ProxyPass --> GuestApp["Container Web App receives request with authentic Client IP"]
```

---

### 6.6b Sites from MY computer: reverse tunnels (Menu 12 > 4)
Your PC has no public address and the router blocks incoming connections. A reverse tunnel solves it: the PC opens a connection **out** to a VPS (allowed everywhere), and the server sends visitors back through it.

```mermaid
flowchart LR
    Visitor["Visitor on the internet"] -->|"http://SERVER-IP:5789"| Host["Main server: port forward (menu 11)"]
    Host --> VPS["Your VPS: tunnel port 5789"]
    PC["Your PC: site on port 5789"] -->|"ssh -R, opened from the PC"| VPS
    VPS -.->|"same connection"| PC
```

**Steps (menu 12 > 4 > Add a tunnel):** choose the VPS, the port to open on the VPS and the port of your site on the PC, then either a **domain** (HTTPS by Caddy) or a **public port** on the server. Then pick your computer:

| Choice | What you get |
|---|---|
| Windows | One line + a password. Paste it once in PowerShell: it installs the key, a hidden auto-start task and a desktop icon (window with On / Off / Delete and the current state). |
| Linux / macOS | A one-line loop that reconnects by itself. |
| More | Try once, create a **new key** (takes access back), or remove a Windows setup. |

**Which address of your PC?** On Windows the name `localhost` can mean `127.0.0.1` (IPv4) or `::1` (IPv6), and a site that listens on only one of them is unreachable through the other. The Windows setup script therefore checks, before every connection, which of the two your site answers on and forwards to that one (it falls back to `localhost` when the site is not running yet). Tunnels made before v2.1.25 keep the old script: delete the tunnel and add it again.

**Who can do what.** The line and password belong to a limited login that exists only for that tunnel port. It cannot open a shell, cannot open any other port and cannot reach other services in the VPS, so it is safe to hand to a friend whose site cannot be exposed otherwise. Cloud firewalls (Oracle VCN, Google VPC) are yours: open the public TCP port there yourself.

**Manage them** in *My tunnels*: one table with each tunnel's state (`ACTIVE - connected`, `ACTIVE - waiting for your PC`, `STOPPED`), and start / stop / edit / delete for one tunnel or for all tunnels of a VPS.

---

### 6.6c VPN: Xray VLESS + Reality (Menu 12 > 5)

Turn a VPS into a VPN for your phones and computers. All their internet goes out through the VPS (its IP, its speed), and to anyone watching it looks like a normal HTTPS visit to `www.speedtest.net` (a stranger who connects to the port really gets speedtest.net).

**Create (12 > 5 > 1):** pick a running VPS and a public port (default 8443). Open **TCP <port>** (the VPN) and **TCP <port>+1** (the QR page) in your cloud firewall. Xray is downloaded from its official GitHub release (checksum checked) and runs as the `vpsforge-vpn` service inside the VPS.

**Add a device (12 > 5 > 2):** a name (e.g. `my-phone`), a **data limit in GB** and a **number of days** (0 = unlimited for either). The device is switched off by itself when one runs out (checked every 5 minutes); **Renew (12 > 5 > 4)** gives it new GB / days from today. The overview shows each device's use (`3.2/50 GB`), days left and whether it is in use.

**Connect:** the free apps **v2rayNG** (Android), **Streisand** or **V2Box** (iPhone), **v2rayN** (Windows). Choose one of:
- **QR page** (easiest): a link like `http://SERVER:8444/<secret>/` that shows the QR code and a *Copy link* button for 10 minutes, then closes (even if a browser keeps a connection open).
- **QR code** in the terminal, or the `vless://` **link** to paste (*Import from clipboard*).

The app shows the name `<server IP>-<VPS>-<days>-<GB>` by itself, e.g. `193.122.84.156-vps3-30d-50GB` (`unl` = unlimited).

**Speed:** measured from Frankfurt to a 1-CPU ARM VPS in Jeddah with Ookla speedtest: about **410 Mbit/s down / 570 up**, against 138 / 310 with WireGuard (the server's single CPU is at 100%: more CPUs give more speed). Normal HTTPS browsing needs even less CPU (Xray's *Vision* passes already-encrypted data through without encrypting it twice).

**Clean:** removing a device stops it at once; removing the VPN (12 > 5 > 6) removes Xray, its service and files from the VPS and its port from the server. Deleting the VPS or `vpsforge uninstall` remove everything too.

---

### 6.7 Snapshots & Compressed Backups (Menu 13)
```mermaid
flowchart TD
    BackupMenu["Snapshots & Backups Menu"] --> Choice{"Select Operation"}
    
    Choice -->|Instant Snapshot| SnapFlow["Create BTRFS CoW Snapshot"]
    SnapFlow --> PurgeSwap["Purge host-backed swapfile inside guest: sh -c 'swapoff /swapfile 2>/dev/null'"]
    PurgeSwap --> IncusSnap["Execute: incus snapshot create vps1 snap-name"]
    IncusSnap --> SnapDone["Completed in under 5ms (0 extra bytes used)"]

    Choice -->|Export Full Backup| ExportFlow["Export Portable .tar.gz"]
    ExportFlow --> ExportPurge["Purge swap inside guest"]
    ExportPurge --> IncusExport["Execute: incus export vps1 /opt/vpsforge-backups/vps1-date.tar.gz"]
    IncusExport --> TarDone["Self-contained backup ready for migration to any server"]
```

---

## 7. ⚙️ Engineering Secrets & Core Algorithms

### 7.1 BTRFS Copy-on-Write & Instant Snapshots
Standard directory storage (`dir`) copies every byte sequentially during snapshots, taking minutes and causing heavy disk I/O. VPSForge forces **BTRFS Copy-on-Write (CoW)**:

```mermaid
graph LR
    subgraph BTRFS_CoW_Storage["BTRFS Storage Pool (Instant & Efficient)"]
        DataBlocks["Original Data Blocks (Block #1, #2, #3)"]
        LiveRef["Live Container Pointer"] --> DataBlocks
        SnapRef["Snapshot Pointer"] --> DataBlocks
        
        NewData["Modified Block #2'"]
        LiveRef -.->|On Write: New block allocated| NewData
    end
```

---

### 7.2 Automated Live Storage Migration
If an existing server has containers running on the default `dir` storage driver, VPSForge automatically migrates them to BTRFS without losing containers or configurations:

```mermaid
flowchart TD
    StartMigration["ensure_setup.sh detects default storage pool is 'dir'"] --> HasContainers{"Are containers present?"}
    HasContainers -->|No| RecreateClean["Delete dir pool & create default btrfs pool"]
    HasContainers -->|Yes| CreateTemp["Create temporary BTRFS pool: temp-btrfs"]
    CreateTemp --> StopRunning["Stop all active containers gracefully"]
    StopRunning --> MoveToTemp["incus move container container -s temp-btrfs"]
    MoveToTemp --> DetachProfiles["Detach root disk device from default profile"]
    DetachProfiles --> DeleteDirPool["Delete legacy 'dir' storage pool"]
    DeleteDirPool --> CreateBtrfsDefault["Create new 'default' pool with btrfs driver"]
    CreateBtrfsDefault --> RebindProfile["Re-bind root disk device to default profile"]
    RebindProfile --> MoveBack["incus move container container -s default"]
    MoveBack --> DestroyTemp["Delete temp-btrfs pool"]
    DestroyTemp --> RestartContainers["Restart containers that were previously running"]
    RestartContainers --> MigrationComplete["Live migration completed seamlessly!"]
```

---

### 7.3 Network Traffic Quota Daemon & TC Throttling
```mermaid
flowchart TD
    CronTrigger["Cron Daemon runs 'vpsforge quota-check' every 5 minutes"] --> ReadIPTables["Parse iptables -nvx -L FORWARD byte counters"]
    ReadIPTables --> ComputeGB["Convert Rx & Tx bytes to Gigabytes for each container"]
    ComputeGB --> CompareLimit{"Usage >= Configured Quota?"}
    
    CompareLimit -->|Yes| CheckIfThrottled{"Already throttled?"}
    CheckIfThrottled -->|Yes| NextContainer["Do nothing, continue"]
    CheckIfThrottled -->|No| ApplyTC["tc qdisc add dev veth root handle 1: tbf rate 1mbit burst 32k latency 400ms"]
    ApplyTC --> MarkThrottled["Mark container as THROTTLED in dashboard"]
    
    CompareLimit -->|No| CheckIfWasThrottled{"Currently throttled?"}
    CheckIfWasThrottled -->|Yes| RemoveTC["tc qdisc del dev veth root (Restore full link speed)"]
    RemoveTC --> UnmarkThrottled["Remove throttle status"]
    CheckIfWasThrottled -->|No| NextContainer
    MarkThrottled --> NextContainer
```

---

### 7.4 SSH 1-Click Repair & Native LXC Container Architecture
Incus system containers run full-system init (`systemd` as PID 1). Rather than using artificial container markers (such as legacy `/.dockerenv`), VPSForge operates on native LXC virtualization detection (`systemd-detect-virt` -> `lxc`).

When guest connectivity or service issues occur, 1-Click Repair restores network interfaces, DNS, and SSH services transparently:

```mermaid
flowchart TD
    SSHFailed["OpenSSH Service fails or hangs on boot"] --> RepairTrigger["User triggers 'Repair Connection'"]
    RepairTrigger --> RefreshProfile["Apply Incus compatibility profile & restart instance"]
    RefreshProfile --> ConfigGuestOpt["Ensure guest locale and clean container environment"]
    ConfigGuestOpt --> ReWriteNet["Re-apply static network configuration inside guest"]
    ReWriteNet --> RestartSSHD["Ensure SSH is installed, configured & active"]
    RestartSSHD --> RebuildNATRules["Rebuild host iptables DNAT forwarding"]
    RebuildNATRules --> SuccessConnect["SSH connection immediately functional!"]
```

---

### 7.5 In-Place Auto-Update & Version Switcher
VPSForge enforces a **Single Source of Truth** architecture with atomic synchronization between the canonical Git repository (`/opt/vpsforge/repo`) and the active production runtime (`/opt/vpsforge`):

```mermaid
flowchart TD
    UpdateRun["User runs: vpsforge update [latest|tag]"] --> SafeStash["Auto-stash uncommitted changes & backup local commits"]
    SafeStash --> FetchAll["Fetch all remote branches & tags from GitHub"]
    FetchAll --> ResolveTarget["Resolve target ref: origin/main, tag, or branch"]
    ResolveTarget --> CheckoutRef["Checkout resolved commit in /opt/vpsforge/repo"]
    CheckoutRef --> StagedBuild["Stage lib/ and vpsforge.sh in temporary staging directory"]
    StagedBuild --> ChmodExec["Apply executable permissions (chmod 755)"]
    ChmodExec --> AtomicSwap["Atomic Swap: replace /opt/vpsforge/lib & purge deleted files"]
    AtomicSwap --> VerifyInstall{"Verify Integrity: diff -r -q active repo?"}
    VerifyInstall -->|Fail| Rollback["Auto-Rollback to previous version backup"]
    VerifyInstall -->|Pass| SaveCommit["Write .installed_commit metadata & refresh symlinks"]
    SaveCommit --> ReExec["Re-exec active script in-memory for instant live reload"]
```

---

## 8. 📂 Project File Directory & Module Structure

**Rule: every function lives in its own file, named after the function, inside a folder named after its topic.**
`lib/load_vpsforge_lib.sh` (`load_vpsforge_lib`) sources every file under `lib/`, so folders can be reorganized freely.

```
vpsforge.sh                  # Entry point & CLI dispatcher
install.sh                   # Installer (records the server's original state first)
release.sh                   # Git release tagging script
scripts/
  check.sh                   # bash -n on every script + one-function-per-file rule
  test.sh                    # Offline unit tests (no root / incus needed)
  e2e.sh                     # End-to-end test of every feature on a real VPS (root)
  space-test.sh              # Measures real disk use of snapshots/backups/deleted VPSs
  ui-test.py                 # Drives every real menu through a terminal and checks the result on the server
  vpn-test.sh                # VPN end to end: devices, limits, QR page, removal (real host, root)
lib/
  load_vpsforge_lib.sh                  # load_vpsforge_lib: loads constants, then every function file
  core/
    common/                  # constants, small helpers (pause, ram_mb, is_valid_username)
    vps/                     # create/ guest/ image/ network/ user/ ssh_port/ state/ preserve/ profile/ reinstall/ repair/
    network/                 # host/ ip/ guest/ ssh/
    firewall/                # rules/ persistence/ bulk/ display/ isolation/ metadata/
    resources/               # cpu/ ram/ disk/ network/ traffic/ host/ allocation/ device/
    selection/               # interactive/ numbering/ parser/
    setup/                   # install/ storage/ compat/ kernel/ update/ preinstall/
    proxy/caddy/             # Caddy install, validate-or-rollback, IP follow, conflict checks
    proxy/tunnel/            # reverse tunnels: records, limited logins, Windows setup script
    proxy/vpn/               # VPN (Xray): install, devices, GB/day limits, QR page, link
    backups/                 # list / delete / clean orphaned backups
    incus/                   # keeps Incus healthy: pause updates, self-test, online repair
    uninstall/               # vpsforge uninstall: puts the server back as it was
  dashboard/
    main/                    # dashboard table + main loop
    1-add ... 14-settings/   # numbered menus; actions grouped in sub-folders (menu/, actions/, selection/ ...)
    dashboard_helper.py      # Python helper that builds the stats table
```

### Keeping the host clean
- Deleting a VPS removes its snapshots, offers to delete its backups, removes its firewall rules and proxy config, and returns the freed space to the real disk (`reclaim_pool_space`; also automatic every Sunday).
- `vpsforge uninstall` removes containers, snapshots, backups, the storage pool, bridge, firewall rules, proxy configs, cron/system files and VPSForge itself, and restores `ip_forward`. It also purges the packages VPSForge installed (using the record in `/opt/vpsforge/.pre_install`). Use `--dry-run` to preview, `--keep-backups` to keep backups.
- `vpsforge tidy` additionally empties the apt cache, trims the system journal (200 MB cap), removes old kernels and deletes damaged backups. It also runs by itself every week (cron).

---

## 9. 🧠 AI / Developer System Reconstruction Guide

If you are an AI assistant or software engineer tasked with building a similar hypervisor manager from scratch, adhere to this exact blueprint:

1. **Choose Incus over Docker:** Docker is containerized process management; Incus provides complete system init containers with persistent networking, custom kernels/modules, and systemd daemons.
2. **Mandate BTRFS or ZFS Storage:** Directory storage (`dir`) is unusable for production hypervisors due to linear disk copy times. Loopback BTRFS image files (`size=25GiB`) provide instant Copy-on-Write branching without requiring dedicated disk partitions.
3. **Deterministic Networking:** Disable DHCP clients inside guest images; write static YAML (Netplan) or interfaces files into the container's rootfs before starting it.
4. **Calculated Port Offsets:** Establish fixed port formulas (`SSH = 9000 + ID`) to eliminate collision tracking complexity.
5. **Real-Time Traffic Accounting with Netfilter:** Place dummy matching rules (`-m comment --comment "vpsforge-quota-$name"`) inside the `FORWARD` table to use Linux's hardware packet counters as a free, high-speed telemetry engine.
6. **Token Bucket Filter (TBF) for Throttling:** Never hard-kill containers exceeding bandwidth quotas; shape their `veth` interface using `tc qdisc` to 1Mbps to keep management SSH channels alive.
7. **Caddy Reverse Proxy Automation:** Use Caddy's `import /etc/caddy/conf.d/*.conf` pattern for atomic, zero-downtime subdomain routing and automated SSL certificate lifecycles.

---

## 10. 💻 CLI Command Reference

Automate VPSForge or integrate it with external billing systems and web control panels using the native CLI:

```bash
vpsforge                         # Launch the interactive terminal dashboard
vpsforge --version               # Check the current version
vpsforge list                    # View a formatted status table of all containers
vpsforge details <vps>           # Print detailed resource, port, proxy, and snapshot metadata
vpsforge start|stop|restart <vps>
vpsforge ram <vps> <MB>          # Set container RAM limit (e.g. vpsforge ram vps1 1024)
vpsforge snapshot <vps> <name>   # Create an instantaneous snapshot
vpsforge backup <vps>            # Export a full self-contained backup (zstd compressed)
vpsforge clone <vps> [new]       # Instant exact copy of a VPS (own IP and SSH port)
vpsforge clean-backups           # List and delete backups whose VPS no longer exists
vpsforge reclaim                 # Give space freed inside the VPS pool back to the real disk
vpsforge tidy                    # reclaim + empty apt cache + trim system logs
vpsforge quota-check             # Traffic quotas, VPN device limits and pending tunnel clean-up (also every 5 minutes by cron)
vpsforge repair-all              # Rebuild all guest static network configs and SSH rules
vpsforge port-forward            # Port-forwarding CLI (add / edit <old rule> <new rule> / delete / list ...)
vpsforge setup                   # Force the full host setup again
vpsforge update [latest|vX.Y.Z]  # Update from GitHub (or switch to a tagged release); --check / --list
vpsforge selftest                # Check that the Incus commands VPSForge needs still work (run after an Incus update)
vpsforge incus status|pin|unpin|repair   # Incus version, pause/allow its updates, repair it
vpsforge uninstall               # Remove everything; --dry-run, --yes, --keep-backups
```

---

## 11. ✅ What was tested and the known limits

**Tested on a real server:** two Oracle Cloud ARM (Ampere) servers, 1 CPU, about 6 GB RAM, Ubuntu 24.04, Incus 6.0, with real VPSs on them. Results for v3.0.0 (tests run on v2.1.32 - v2.1.35, the code of this release):

| Test | Result |
|---|---|
| `scripts/test.sh` (offline, no root) | 113 / 113 |
| `vpsforge selftest` (Incus compatibility) | 14 / 14 |
| `scripts/e2e.sh` (creates its own VPS and tries every feature) | 90 / 90 and 89 / 89 |
| `scripts/ui-test.py` (types into every real menu) | 87 / 87 |
| `scripts/vpn-test.sh` (VPN devices, limits, QR page, removal) | 52 / 52 |
| `scripts/space-test.sh` (snapshots, backups, deleted VPSs leave no files behind) | clean |
| `vpsforge uninstall` on a server with other Incus containers, then reinstall | packages and iptables back as before, other containers kept |

The Windows tunnel script was tried on Windows 10 with Windows OpenSSH against a real tunnel.

**Not tried at all:** x86 servers, other cloud providers, other host systems than Ubuntu 24.04, the VPN inside Alpine / Debian / Rocky VPSs (the installer has paths for them), and the Linux / macOS tunnel line with a site that listens on one address only.

**Limits you should know:**
- Every VPS is **Isolated (unprivileged)**: root inside a VPS is an ordinary user on the server (uid 1000000), so a VPS can be rented to strangers. Docker works in it through crun + fuse-overlayfs. CPU, RAM, network and normal disk use run at full speed; only writes inside a Docker container's own layer (image pulls, builds) go through FUSE and are slower, so keep heavy data in Docker volumes (`-v`), which are native.
- The Docker helpers (crun and fuse-overlayfs) are downloaded once per server from their GitHub releases (sha256 checked); without internet access to GitHub, Docker inside new VPSs will not start.
- The **VPN speed is limited by the CPU of the server**: about 410 Mbit/s down / 570 up on 1 ARM CPU (Frankfurt to Jeddah, Ookla). More CPUs give more speed. Your own internet and the route to the server are limits too.
- The VPN needs TCP ports (the VPN port and the next one for the QR page) open in the **cloud provider's firewall**, not only on the server.
- Xray is downloaded from its GitHub release (checksum checked) when a VPN is created, so the VPS needs internet access to GitHub.
- A free 1-CPU server cannot give 1 Gbit/s through a VPN; for that use 2-4 CPUs.

---

## 📄 License

VPSForge is open-source software licensed under the [MIT License](LICENSE).
