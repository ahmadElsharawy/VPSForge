#!/usr/bin/env python3
import sys
import json
import re
import os
import subprocess
import concurrent.futures

def parse_bytes(size_str):
    if not size_str:
        return 0
    size_str = str(size_str).lower().strip()
    match = re.match(r'^([\d.]+)\s*([a-z]*)$', size_str)
    if not match:
        return 0
    val, unit = match.groups()
    val = float(val)
    if unit in ('g', 'gib', 'gb'):
        return int(val * 1024 * 1024 * 1024)
    if unit in ('m', 'mib', 'mb'):
        return int(val * 1024 * 1024)
    if unit in ('k', 'kib', 'kb'):
        return int(val * 1024)
    return int(val)

def human_bytes(b):
    if b >= 1073741824: return f"{b/1073741824:.1f}G"
    if b >= 1048576:    return f"{b/1048576:.1f}M"
    if b >= 1024:       return f"{b/1024:.0f}K"
    return f"{b}B"

def get_disk_limit_gb(vps):
    for devices_dict in (vps.get('devices', {}), vps.get('expanded_devices', {})):
        if not devices_dict:
            continue
        for dev_name, dev_info in devices_dict.items():
            if isinstance(dev_info, dict) and dev_info.get('type') == 'disk' and dev_info.get('path') == '/':
                size = dev_info.get('size')
                if size:
                    return parse_bytes(size) / (1024**3)
    return 0.0

def get_network_limit_mbit(vps, host_net_mbit):
    for devices_dict in (vps.get('devices', {}), vps.get('expanded_devices', {})):
        if not devices_dict:
            continue
        for dev_name, dev_info in devices_dict.items():
            if isinstance(dev_info, dict) and dev_info.get('type') == 'nic':
                ingress = dev_info.get('limits.ingress')
                if ingress:
                    match = re.search(r'(\d+)', str(ingress))
                    if match:
                        return int(match.group(1))
    return host_net_mbit

def get_vps_disk_usage(name, status, pool_path):
    usage_gb = 0.0

    # 1. First, try checking host-side directory size of the container (extremely fast, works for RUNNING and STOPPED)
    container_found = False
    for path in [
        os.path.join(pool_path, "containers", name),
        f"/var/lib/incus/storage-pools/default/containers/{name}",
        f"/var/lib/lxd/storage-pools/default/containers/{name}"
    ]:
        if os.path.exists(path):
            try:
                res = subprocess.run(
                    ["du", "-s", "-B1", path],
                    capture_output=True, text=True, timeout=2
                )
                if res.returncode == 0:
                    val = int(res.stdout.split()[0])
                    if val > 0:
                        usage_gb = val / (1024**3)
                        container_found = True
                        break
            except Exception:
                pass

    # 2. If host directory check failed or not found, try incus query (only if running)
    if not container_found and status == "RUNNING":
        try:
            res = subprocess.run(
                ["incus", "query", f"/1.0/instances/{name}/state"],
                capture_output=True, text=True, timeout=2
            )
            if res.returncode == 0:
                data = json.loads(res.stdout)
                disk = data.get("disk", {})
                usage = 0
                for dev, info in disk.items():
                    if isinstance(info, dict):
                        u = info.get("usage", 0)
                        if u and int(u) > usage:
                            usage = int(u)
                if usage > 0:
                    usage_gb = usage / (1024**3)
                    container_found = True
        except Exception:
            pass

    # 3. Last fallback: incus exec du inside container (only if running)
    if not container_found and status == "RUNNING":
        try:
            res = subprocess.run(
                ["incus", "exec", name, "--", "sh", "-c", "du -s -B1 --exclude=/proc --exclude=/sys --exclude=/dev / 2>/dev/null | awk '{print $1}'"],
                capture_output=True, text=True, timeout=5
            )
            if res.returncode == 0:
                val = int(res.stdout.strip() or 0)
                usage_gb = val / (1024**3)
        except Exception:
            pass

    # 4. Now, check snapshots directory size and add it to the total
    snapshots_used_gb = 0.0
    for path in [
        os.path.join(pool_path, "containers-snapshots", name),
        f"/var/lib/incus/storage-pools/default/containers-snapshots/{name}",
        f"/var/lib/lxd/storage-pools/default/containers-snapshots/{name}"
    ]:
        if os.path.exists(path):
            try:
                res = subprocess.run(
                    ["du", "-s", "-B1", path],
                    capture_output=True, text=True, timeout=2
                )
                if res.returncode == 0:
                    val = int(res.stdout.split()[0])
                    if val > 0:
                        snapshots_used_gb = val / (1024**3)
                        break
            except Exception:
                pass

    return usage_gb + snapshots_used_gb

def main():
    only_table = "--only-table" in sys.argv

    if not only_table and len(sys.argv) < 6:
        print("Usage: dashboard_helper.py <incus_pool_path> <total_network_mbit> <auto_refresh> <refresh_interval> <public_ip> <version> [--only-table]")
        sys.exit(1)

    pool_path = sys.argv[1] if len(sys.argv) > 1 else "/"
    host_net_mbit = int(sys.argv[2]) if len(sys.argv) > 2 else 10000
    auto_refresh = sys.argv[3] if len(sys.argv) > 3 else "off"
    refresh_interval = sys.argv[4] if len(sys.argv) > 4 else "10"
    public_ip = sys.argv[5] if len(sys.argv) > 5 else "127.0.0.1"
    version = sys.argv[6] if len(sys.argv) > 6 else "v1.0.0"

    # Read incus json from stdin
    try:
        containers = json.loads(sys.stdin.read())
    except Exception as e:
        print(f"Error parsing Incus JSON: {e}")
        sys.exit(1)

    # Read iptables NAT rules once
    iptables_output = ""
    try:
        iptables_output = subprocess.getoutput("iptables -t nat -S PREROUTING 2>/dev/null")
    except Exception:
        pass

    ip_to_port = {}
    for line in iptables_output.splitlines():
        if "DNAT" in line and "--to-destination" in line:
            dport_match = re.search(r'--dport\s+(\d+)', line)
            to_dest_match = re.search(r'--to-destination\s+([\d.]+):22', line)
            if dport_match and to_dest_match:
                ip_to_port[to_dest_match.group(1)] = dport_match.group(1)

    # Host memory details
    host_total_ram_mb = 0
    host_avail_ram_mb = 0
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if "MemTotal" in line:
                    host_total_ram_mb = int(int(line.split()[1]) / 1024)
                elif "MemAvailable" in line:
                    host_avail_ram_mb = int(int(line.split()[1]) / 1024)
    except Exception:
        pass

    # Host CPU count
    host_cpu_count = os.cpu_count() or 1

    # Host disk details using statvfs on root filesystem "/"
    disk_total_gb = 0
    disk_avail_gb = 0
    try:
        stat = os.statvfs("/")
        disk_total_gb = (stat.f_blocks * stat.f_frsize) / (1024**3)
        disk_avail_gb = (stat.f_bavail * stat.f_frsize) / (1024**3)
    except Exception:
        pass

    # Read backups size
    backup_dir = "/opt/vpsforge-backups"
    backup_used_bytes = 0
    if os.path.exists(backup_dir):
        try:
            for root_dir, dirs, files in os.walk(backup_dir):
                for f in files:
                    fp = os.path.join(root_dir, f)
                    if os.path.exists(fp) and not os.path.islink(fp):
                        backup_used_bytes += os.path.getsize(fp)
        except Exception:
            pass
    backup_used_gb = backup_used_bytes / (1024**3)

    # Resolve disk usages in parallel using ThreadPoolExecutor
    disk_usages = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = {
            executor.submit(get_vps_disk_usage, vps.get('name'), vps.get('status', '').upper(), pool_path): vps.get('name')
            for vps in containers
        }
        for future in concurrent.futures.as_completed(futures):
            name = futures[future]
            try:
                disk_usages[name] = future.result()
            except Exception:
                disk_usages[name] = 0.0

    allocated_ram_mb = 0
    disk_allocated_gb = 0
    disk_used_gb_total = sum(disk_usages.values())

    rows = []
    for vps in containers:
        name = vps.get('name', '')
        status = vps.get('status', '').upper()
        config = vps.get('config', {}) or {}
        expanded_config = vps.get('expanded_config', {}) or {}
        state = vps.get('state', {}) or {}

        # 1. RAM limit and usage
        ram_limit_raw = expanded_config.get('limits.memory', '')
        ram_limit_bytes = parse_bytes(ram_limit_raw)
        ram_limit_mb = int(ram_limit_bytes / (1024**2))
        allocated_ram_mb += ram_limit_mb

        ram_used_bytes = state.get('memory', {}).get('usage', 0) or 0
        ram_used_mb = int(ram_used_bytes / (1024**2))
        if ram_limit_mb > 0:
            ram_str = f"{ram_used_mb}MB / {ram_limit_mb}MB"
        else:
            ram_str = f"{ram_used_mb}MB / {host_avail_ram_mb}MB"

        # 2. CPU cores
        cpu_limit = config.get('limits.cpu', '') or expanded_config.get('limits.cpu', '')
        if cpu_limit:
            cpu_str = f"{cpu_limit} Core" + ("" if str(cpu_limit) == "1" else "s")
        else:
            cpu_str = f"{host_cpu_count} Core" + ("" if str(host_cpu_count) == "1" else "s")

        # 3. Disk limit and usage
        vps_disk_limit = get_disk_limit_gb(vps)
        disk_allocated_gb += int(vps_disk_limit)
        vps_disk_used = disk_usages.get(name, 0.0)

        if vps_disk_limit > 0:
            disk_str = f"{vps_disk_used:.1f}GB / {int(vps_disk_limit)}GB"
        else:
            disk_str = f"{vps_disk_used:.1f}GB / {disk_avail_gb:.1f}GB"

        # 4. Network Limit and IO
        net_limit = get_network_limit_mbit(vps, host_net_mbit)
        eth0 = (state.get('network', {}) or {}).get('eth0', {}) or {}
        counters = eth0.get('counters', {}) or {}
        rx = int(counters.get('bytes_received', 0) or 0)
        tx = int(counters.get('bytes_sent', 0) or 0)

        rx_lim = int(config.get('user.vpsforge.traffic.rx_limit_gb', 0) or 0)
        tx_lim = int(config.get('user.vpsforge.traffic.tx_limit_gb', 0) or 0)
        t_status = config.get('user.vpsforge.traffic.status', '')

        rx_str = human_bytes(rx) + (f"/{rx_lim}G" if rx_lim > 0 else "")
        tx_str = human_bytes(tx) + (f"/{tx_lim}G" if tx_lim > 0 else "")
        io_str = f"↓{rx_str} ↑{tx_str}"
        if t_status:
            io_str += f" [⚠️{t_status}]"

        net_str = f"{net_limit}M [{io_str}]"

        # 5. IP & Port
        ip = config.get('user.vpsforge.ip', '')
        if not ip or ip == "-":
            addresses = eth0.get('addresses', []) or []
            for addr in addresses:
                if addr.get('family') == 'inet':
                    ip = addr.get('address', '')
                    break
        if not ip:
            ip = "-"

        port = "-"
        if ip != "-":
            port = ip_to_port.get(ip, "")
            if not port:
                port = config.get('user.vpsforge.ssh_port', '')
        if not port:
            port = "-"

        rows.append((name, status, ram_str, cpu_str, disk_str, net_str, ip, port))

    # Calculate remaining host RAM
    remaining_ram_mb = host_total_ram_mb - allocated_ram_mb

    # Host OS usage is the remaining used space on the filesystem
    used_gb = disk_total_gb - disk_avail_gb
    host_os_gb = used_gb - (disk_used_gb_total + backup_used_gb)
    if host_os_gb < 0:
        host_os_gb = max(0.0, used_gb - backup_used_gb)
        disk_total_gb = host_os_gb + disk_used_gb_total + backup_used_gb + disk_avail_gb

    # Print dashboard header
    if not only_table:
        refresh_str = f"ON ({refresh_interval}s)" if auto_refresh == "on" else "OFF"
        host_cpu_str = f"{host_cpu_count} Core" + ("" if str(host_cpu_count) == "1" else "s")

        header_border = "+" + "-" * 140 + "+"
        grid_border = "+" + "+".join([
            "-" * 22, # AUTO REFRESH / TOTAL DISK
            "-" * 22, # PUBLIC IP / HOST OS
            "-" * 22, # TOTAL RAM / VPS DISK USED
            "-" * 22, # VPS RAM LIMITS / BACKUPS
            "-" * 22, # REMAINING RAM / VPS DISK LIMITS
            "-" * 25  # HOST CPU / AVAILABLE DISK
        ]) + "+"

        print(header_border)
        print(f"| {('VPSFORGE MANAGER ' + version):^138} |")
        print(grid_border)
        print(f"| {'AUTO REFRESH':<20} | {'PUBLIC IP':<20} | {'TOTAL RAM':<20} | {'VPS RAM LIMITS':<20} | {'REMAINING RAM':<20} | {'HOST CPU':<23} |")
        print(grid_border)
        print(f"| {refresh_str:<20} | {public_ip:<20} | {f'{host_total_ram_mb}MB':<20} | {f'{allocated_ram_mb}MB':<20} | {f'{remaining_ram_mb}MB':<20} | {host_cpu_str:<23} |")
        print(grid_border)
        print(f"| {'TOTAL DISK':<20} | {'HOST OS':<20} | {'VPS DISK USED':<20} | {'BACKUPS':<20} | {'VPS DISK LIMITS':<20} | {'AVAILABLE DISK':<23} |")
        print(grid_border)
        print(f"| {f'{disk_total_gb:.1f}GB':<20} | {f'{host_os_gb:.1f}GB':<20} | {f'{disk_used_gb_total:.1f}GB':<20} | {f'{backup_used_gb:.1f}GB':<20} | {f'{disk_allocated_gb}GB':<20} | {f'{disk_avail_gb:.1f}GB':<23} |")
        print(grid_border)
        print()

    # Print container list
    border = "+" + "+".join([
        "-" * 12, # NAME
        "-" * 12, # STATUS
        "-" * 20, # RAM
        "-" * 12, # CPU
        "-" * 20, # DISK
        "-" * 32, # NETWORK_IO
        "-" * 17, # INTERNAL_IP
        "-" * 8   # PORT
    ]) + "+"

    print(border)
    print(f"| {'NAME':<10} | {'STATUS':<10} | {'RAM':<18} | {'CPU':<10} | {'DISK':<18} | {'NETWORK_IO':<30} | {'INTERNAL_IP':<15} | {'PORT':<6} |")
    print(border)
    for row in sorted(rows, key=lambda x: x[0]):
        print(f"| {row[0]:<10} | {row[1]:<10} | {row[2]:<18} | {row[3]:<10} | {row[4]:<18} | {row[5]:<30} | {row[6]:<15} | {row[7]:<6} |")
        print(border)

if __name__ == "__main__":
    main()
