# VPSForge v2.0.0

<p align="center">
  <img src="https://img.shields.io/badge/Version-v2.0.0-blue?style=for-the-badge&logo=git" alt="Version" />
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
    subgraph Host_Node["Host Server (Public IP: 158.101.236.52)"]
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
    Main --> M12["12) Domains & SSL"]
    Main --> M13["13) Snapshots & Backups"]
    Main --> M14["14) Settings & Updates"]
    Main --> M15["0) Exit"]

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
- `vpsforge tidy` additionally empties the apt cache and trims system logs.

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
vpsforge quota-check             # Manually execute the traffic quota verification daemon
vpsforge repair-all              # Rebuild all guest static network configs and SSH rules
vpsforge port-forward            # Port-forwarding CLI (add / delete / list ...)
vpsforge setup                   # Force the full host setup again
vpsforge update [latest|vX.Y.Z]  # Update from GitHub (or switch to a tagged release); --check / --list
vpsforge selftest                # Check that the Incus commands VPSForge needs still work (run after an Incus update)
vpsforge incus status|pin|unpin|repair   # Incus version, pause/allow its updates, repair it
vpsforge uninstall               # Remove everything; --dry-run, --yes, --keep-backups
```

---

## 📄 License

VPSForge is open-source software licensed under the [MIT License](LICENSE).
