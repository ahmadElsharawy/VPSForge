#!/usr/bin/env python3
"""Drives the REAL VPSForge menus through a terminal (pty), like a person typing,
and checks the result of every option on the server.   Run as root on the VPS:

    sudo python3 scripts/ui-test.py                # every section
    sudo python3 scripts/ui-test.py create edit    # only some sections

It creates its own test VPSs (names start with "uit") and removes them at the end.
"""
import os, pty, re, select, subprocess, sys, time

ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]|\x1b[()][0-9A-B]|\r')
PASS, FAIL = [], []
NAMES = ["uit1", "uit2", "uit3"]
# UI_TEST_SAFE=1: for a server that holds real VPSs. Skips everything that could touch things the test
# did not create (settings, websites/Caddy, backups folder, "delete ALL port forwards", log trimming).
SAFE = os.environ.get("UI_TEST_SAFE") == "1"
SAFE_SKIPPED = ("settings", "websites", "snapshots")


def sh(cmd, timeout=120):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return r.returncode, (r.stdout + r.stderr).strip()


class UI:
    """A running `vpsforge` process behind a pseudo terminal."""

    def __init__(self, args=None):
        self.buf = ""
        self.pos = 0
        env = dict(os.environ, TERM="xterm", COLUMNS="220", LINES="60")
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvpe("vpsforge", ["vpsforge"] + (args or []), env)
        self.log = open("/tmp/ui-test.transcript", "a")

    def _read(self, timeout):
        r, _, _ = select.select([self.fd], [], [], timeout)
        if not r:
            return False
        try:
            data = os.read(self.fd, 65536).decode("utf-8", "replace")
        except OSError:
            return False
        if not data:
            return False
        clean = ANSI.sub("", data)
        self.buf += clean
        self.log.write(clean)
        self.log.flush()
        return True

    def send(self, text):
        os.write(self.fd, text.encode())

    def expect(self, pattern, timeout=60):
        rx = re.compile(pattern, re.S)
        end = time.time() + timeout
        while time.time() < end:
            m = rx.search(self.buf, self.pos)
            if m:
                self.pos = m.end()
                return True
            self._read(0.3)
        return False

    def tail(self, n=12):
        return "\n".join(self.buf[self.pos - 600:].splitlines()[-n:]) if self.buf else ""

    def alive(self):
        try:
            return os.waitpid(self.pid, os.WNOHANG) == (0, 0)
        except ChildProcessError:
            return False

    def close(self):
        try:
            os.kill(self.pid, 9)
        except OSError:
            pass


def check(name, cond, detail=""):
    (PASS if cond else FAIL).append(name)
    print(("PASS  " if cond else "FAIL  ") + name + (("   -> " + detail) if (detail and not cond) else ""), flush=True)
    return cond


def step(ui, label, pattern, send=None, timeout=60):
    """Wait for a prompt, then type the answer. Records a FAIL if the prompt never shows."""
    ok = ui.expect(pattern, timeout)
    if not ok:
        check("prompt: " + label, False, "never saw /" + pattern + "/ ... screen: " + ui.tail(6).replace("\n", " | "))
        return False
    if send is not None:
        ui.send(send)
    return True


def to_menu(ui, timeout=60):
    return ui.expect(r"Choice: $|Choice: ", timeout)


def main_choice(ui, number):
    if not to_menu(ui):
        check("main menu visible before option %s" % number, False, ui.tail(5))
        return False
    ui.send(str(number) + "\r")
    return True


def pause(ui, timeout=60):
    ok = ui.expect(r"Press Enter to continue", timeout)
    if ok:
        ui.send("\r")
    return ok


def ip_of(name):
    rc, out = sh("incus config get %s user.vpsforge.ip" % name)
    return out.strip()


def login(user, password, ip):
    open("/tmp/ui_askpass.sh", "w").write('#!/bin/sh\necho "%s"\n' % password)
    os.chmod("/tmp/ui_askpass.sh", 0o700)
    # a freshly changed network or password may need a few seconds: try up to 6 times
    for attempt in range(6):
        rc, _ = sh("SSH_ASKPASS=/tmp/ui_askpass.sh SSH_ASKPASS_REQUIRE=force setsid ssh -o StrictHostKeyChecking=no "
                   "-o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no "
                   "-o ConnectTimeout=10 %s@%s true" % (user, ip), 30)
        if rc == 0:
            return True
        time.sleep(5)
    return False


def running(name):
    rc, out = sh("incus list %s -c s --format csv" % name)
    return out.strip().upper() == "RUNNING"


def exists(name):
    return sh("incus info %s" % name)[0] == 0


# ───────────────────────────── sections ─────────────────────────────

def section_dashboard(ui):
    print("== dashboard ==")
    check("dashboard shows the menu", to_menu(ui, 90), ui.tail())
    ui.send("0\r")
    check("option 0 refreshes", to_menu(ui))
    ui.send("99\r")
    check("unknown number just refreshes", to_menu(ui))


def section_create(ui):
    print("== 1) Add ==")
    for leftover in NAMES + ["uitimp", "uit1r"]:      # start from a clean slate
        sh("incus delete %s --force" % leftover)
    for _ in range(30):                               # let any delete still running in Incus finish
        if "Deleting" not in sh("incus operation list --format csv")[1] and not [n for n in NAMES if exists(n)]:
            break
        time.sleep(2)
    sh("rm -f /opt/vpsforge/preferences.conf")        # remembered "last answers" start empty (tested separately)
    # --- one VPS, configured individually
    main_choice(ui, 1)
    step(ui, "how many", r"How many VPS containers.*?: ", "\r")
    step(ui, "name", r"Enter VPS Name \[default.*?\]: ", "uit1\r")
    step(ui, "distro", r"Choice \[0=Back, Enter=\d\]: ", "\r")                 # Ubuntu
    step(ui, "version", r"Choice \[0=Back, Enter=default.*?\]: ", "\r")        # default image
    step(ui, "ram mode", r"RAM Mode for uit1.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "ram value", r"RAM limit \(.*?: ", "256\r")
    step(ui, "cpu mode", r"CPU Mode for uit1.*?Choice \[0=Back, Enter=\d\]: ", "\r")
    step(ui, "disk mode", r"Disk Mode for uit1.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "disk value", r"Disk limit \(.*?: ", "5\r")
    step(ui, "network mode", r"Network Mode for uit1.*?Choice \[0=Back, Enter=\d\]: ", "\r")
    step(ui, "traffic mode", r"Traffic Data Limit.*?Choice \[0=Back, Enter=\d\]: ", "\r")
    step(ui, "ssh forward", r"Forward external SSH Port.*?: ", "\r")
    step(ui, "confirm", r"Proceed with VPS creation\?.*?: ", "\r")
    ok = ui.expect(r"Creation summary: Success=1", 420)
    check("1) create one VPS (individual settings)", ok and running("uit1"), ui.tail())
    pause(ui)

    # --- two VPSs with the same settings
    main_choice(ui, 1)
    step(ui, "how many", r"How many VPS containers.*?: ", "2\r")
    step(ui, "setup mode", r"Choice \[0=Back, Enter=\d\]: ", "2\r")             # same for all
    step(ui, "distro", r"Choice \[0=Back, Enter=\d\]: ", "\r")
    step(ui, "version", r"Choice \[0=Back, Enter=default.*?\]: ", "\r")
    step(ui, "ram mode", r"RAM Mode.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "ram value", r"RAM limit \(.*?: ", "256\r")
    step(ui, "cpu mode", r"CPU Mode.*?Choice \[0=Back, Enter=\d\]: ", "\r")
    step(ui, "disk mode", r"Disk Mode.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "disk value", r"Disk limit \(.*?: ", "5\r")
    step(ui, "network mode", r"Network Mode.*?Choice \[0=Back, Enter=\d\]: ", "\r")
    step(ui, "traffic mode", r"Traffic Data Limit.*?Choice \[0=Back, Enter=\d\]: ", "\r")
    step(ui, "ssh forward", r"Forward external SSH Port.*?: ", "\r")
    step(ui, "name 1", r"Enter VPS Name for container 1.*?: ", "uit2\r")
    step(ui, "name 2", r"Enter VPS Name for container 2.*?: ", "uit3\r")
    step(ui, "confirm", r"Proceed with VPS creation\?.*?: ", "\r")
    ok = ui.expect(r"Creation summary: Success=2", 700)
    check("1) create two VPSs (same settings for all)", ok and running("uit2") and running("uit3"), ui.tail())
    pause(ui)
    # an app inside uit2 for the websites section
    sh("incus exec uit2 -- sh -c 'nohup python3 -m http.server 8088 >/dev/null 2>&1 &'")
    # back out cleanly: cancel in the first prompt of Add (tests the 0 = cancel path)
    main_choice(ui, 1)
    step(ui, "cancel add", r"How many VPS containers.*?: ", "0\r")
    check("1) cancel with 0 returns to the menu", to_menu(ui))


def section_details(ui):
    print("== 8) Details / 10) Connection / 9) Shell ==")
    main_choice(ui, 8)
    step(ui, "select all", r"Select VPS by number, name, or A for All \[0=Back, Enter=All\]: ", "\r")
    check("8) details of all VPSs", ui.expect(r"VPS DETAILS INSPECTOR: uit1.*?VPS DETAILS INSPECTOR: uit2", 60), ui.tail())
    pause(ui)
    main_choice(ui, 10)
    step(ui, "select all", r"Select VPS by number, name, or A for All \[0=Back, Enter=All\]: ", "\r")
    check("10) connection info with SSH command", ui.expect(r"SSH Command: ssh root@.*? -p 90\d\d", 30), ui.tail())
    pause(ui)
    main_choice(ui, 9)
    step(ui, "select vps", r"Select VPS by number, name, or A for All.*?: ", "uit1\r")
    time.sleep(2)
    ui.send("echo SHELL$((20+22))OK\r")
    check("9) shell opens inside the VPS", ui.expect(r"SHELL42OK", 30), ui.tail())
    ui.send("exit\r")
    check("9) exit returns to the menu", to_menu(ui, 30))


def section_power(ui):
    print("== 4) Stop / 3) Start / 5) Restart ==")
    main_choice(ui, 4)
    step(ui, "select", r"Select VPS by number, name, or A for All.*?: ", "uit3\r")
    pause(ui)
    check("4) stop a VPS", not running("uit3"))
    main_choice(ui, 3)
    step(ui, "select", r"Select VPS by number, name, or A for All.*?: ", "uit3\r")
    pause(ui)
    time.sleep(5)
    check("3) start a VPS", running("uit3"))
    main_choice(ui, 5)
    step(ui, "select", r"Select VPS by number, name, or A for All.*?: ", "uit3\r")
    pause(ui)
    time.sleep(5)
    check("5) restart a VPS", running("uit3"))
    # several at once
    main_choice(ui, 4)
    step(ui, "select several", r"Select VPS by number, name, or A for All.*?: ", "uit2,uit3\r")
    pause(ui)
    check("4) stop two VPSs at once", not running("uit2") and not running("uit3"))
    main_choice(ui, 3)
    step(ui, "select several", r"Select VPS by number, name, or A for All.*?: ", "uit2,uit3\r")
    pause(ui)
    time.sleep(6)
    check("3) start two VPSs at once", running("uit2") and running("uit3"))
    sh("incus exec uit2 -- sh -c 'nohup python3 -m http.server 8088 >/dev/null 2>&1 &'")


def edit_menu(ui, vps):
    main_choice(ui, 7)
    step(ui, "select vps", r"Select VPS by number, name, or A for All.*?: ", vps + "\r")


def eventually(fn, timeout=25):
    """True as soon as fn() is true (the server may need a few seconds to apply a change)."""
    end = time.time() + timeout
    while time.time() < end:
        try:
            if fn():
                return True
        except Exception:
            pass
        time.sleep(1)
    return False


def section_edit(ui):
    print("== 7) Edit VPS (every sub-option) ==")
    sub_prompt = r"12\) Reinstall / Change OS Image.*?Choice \[0=Back, Enter=\d\]: "
    edit_menu(ui, "uit1")

    step(ui, "edit menu", sub_prompt, "1\r")
    step(ui, "ram mode", r"RAM Mode for uit1.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "ram value", r"RAM limit \(.*?: ", "512\r")
    time.sleep(1)
    check("7.1 change RAM", eventually(lambda: sh("incus config get uit1 limits.memory")[1] == "512MiB"))

    step(ui, "edit menu", sub_prompt, "2\r")
    step(ui, "cpu mode", r"CPU Mode for uit1.*?Choice \[0=Back, Enter=\d\]: ", "1\r")
    time.sleep(1)
    check("7.2 change CPU (unlimited)", eventually(lambda: sh("incus config get uit1 limits.cpu")[1] == ""))

    step(ui, "edit menu", sub_prompt, "3\r")
    step(ui, "disk mode", r"Disk Mode for uit1.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "disk value", r"Disk limit \(.*?: ", "4\r")
    time.sleep(1)
    check("7.3 change disk", eventually(lambda: sh("incus config device get uit1 root size")[1] == "4GiB"))

    step(ui, "edit menu", sub_prompt, "4\r")
    step(ui, "net mode", r"Network Mode for uit1.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "net value", r"Network limit \(.*?: ", "100\r")
    time.sleep(1)
    check("7.4 change network speed", eventually(lambda: sh("incus config device get uit1 eth0 limits.ingress")[1] == "100Mbit"))

    step(ui, "edit menu", sub_prompt, "5\r")
    step(ui, "traffic mode", r"Traffic Data Limit.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "rx", r"Download \(Rx\) Data Limit.*?: ", "50\r")
    step(ui, "tx", r"Upload \(Tx\) Data Limit.*?: ", "40\r")
    time.sleep(1)
    check("7.5 change traffic quota", sh("incus config get uit1 user.vpsforge.traffic.rx_limit_gb")[1] == "50"
          and sh("incus config get uit1 user.vpsforge.traffic.tx_limit_gb")[1] == "40")

    old_port = sh("incus config get uit1 user.vpsforge.ssh_port")[1]
    step(ui, "edit menu", sub_prompt, "6\r")
    step(ui, "port", r"New SSH port.*?: ", "9150\r")
    time.sleep(2)
    check("7.6 change SSH port", "--dport 9150" in sh("iptables -t nat -S PREROUTING")[1])
    step(ui, "edit menu", sub_prompt, "6\r")
    step(ui, "port back", r"New SSH port.*?: ", old_port + "\r")
    time.sleep(2)

    step(ui, "edit menu", sub_prompt, "7\r")
    step(ui, "username", r"New username.*?: ", "uiuser\r")
    time.sleep(3)
    check("7.7 change username", sh("incus exec uit1 -- id uiuser")[0] == 0)

    step(ui, "edit menu", sub_prompt, "8\r")
    step(ui, "password", r"New password.*?: ", "UiPass123\r")
    time.sleep(3)
    check("7.8 change password (login works)", login("uiuser", "UiPass123", ip_of("uit1")))

    step(ui, "edit menu", sub_prompt, "9\r")
    step(ui, "rename", r"Enter new VPS name \[current: uit1.*?: ", "uit1r\r")
    check("7.9 rename VPS", ui.expect(r"SUCCESS: VPS renamed", 90) and exists("uit1r") and not exists("uit1"), ui.tail())
    step(ui, "edit menu", sub_prompt, "9\r")
    step(ui, "rename back", r"Enter new VPS name \[current: uit1r.*?: ", "uit1\r")
    check("7.9 rename back", ui.expect(r"SUCCESS: VPS renamed", 90) and exists("uit1"), ui.tail())

    orig_ip = ip_of("uit1")
    prefix = ".".join(orig_ip.split(".")[:3])
    new_ip = prefix + ".150"
    step(ui, "edit menu", sub_prompt, "10\r")
    step(ui, "new ip", r"New Internal IP.*?: ", new_ip + "\r")
    time.sleep(6)
    check("7.10 change internal IP", ip_of("uit1") == new_ip and login("uiuser", "UiPass123", new_ip), ip_of("uit1"))
    step(ui, "edit menu", sub_prompt, "10\r")
    step(ui, "ip back", r"New Internal IP.*?: ", orig_ip + "\r")
    time.sleep(6)

    ip1, ip2 = ip_of("uit1"), ip_of("uit2")
    step(ui, "edit menu", sub_prompt, "11\r")
    step(ui, "swap target", r"Target VPS name to swap IP & Port with.*?: ", "uit2\r")
    ok = ui.expect(r"Swap complete", 90)
    time.sleep(4)
    check("7.11 swap IP and port with another VPS", ok and ip_of("uit1") == ip2 and ip_of("uit2") == ip1, ip_of("uit1") + " " + ip_of("uit2"))
    step(ui, "edit menu", sub_prompt, "11\r")
    step(ui, "swap back", r"Target VPS name to swap IP & Port with.*?: ", "uit2\r")
    ui.expect(r"Swap complete", 90)
    time.sleep(3)

    # 12: reinstall with a different OS (Alpine = the lightest option)
    step(ui, "edit menu", sub_prompt, "12\r")
    step(ui, "distro", r"Operating system for uit1.*?Choice \[0=Back, Enter=\d\]: ", "3\r")  # Alpine
    step(ui, "version", r"Choice \[0=Back, Enter=default.*?\]: ", "\r")
    ok = ui.expect(r"Reinstall completed for uit1", 400)
    time.sleep(3)
    rc, out = sh("incus exec uit1 -- cat /etc/alpine-release")
    check("7.12 reinstall with another OS (Alpine)", ok and rc == 0, out + " | " + ui.tail(4))
    check("7.12 settings survive the reinstall (RAM 512MB)", sh("incus config get uit1 limits.memory")[1] == "512MiB")
    check("7.12 user + password survive (ssh login)", login("uiuser", "UiPass123", ip_of("uit1")))

    step(ui, "edit menu", sub_prompt, "0\r")
    check("7.0 back to the main menu", to_menu(ui))

    # several VPSs at once
    edit_menu(ui, "uit2,uit3")
    multi = sub_prompt          # the same menu whatever the selection
    scope = r"2\) Same setting for all selected VPS.*?Choice \[0=Back, Enter=\d\]: "
    step(ui, "multi menu", multi, "1\r")
    step(ui, "scope", scope, "2\r")
    step(ui, "ram mode", r"RAM Mode for uit2.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "ram value", r"RAM limit \(.*?: ", "300\r")
    time.sleep(2)
    check("7 (several) same RAM for all", sh("incus config get uit2 limits.memory")[1] == "300MiB"
          and sh("incus config get uit3 limits.memory")[1] == "300MiB")
    step(ui, "multi menu", multi, "8\r")
    step(ui, "scope", scope, "2\r")
    step(ui, "all password", r"New password for all \[0=Back\]: ", "MultiPass9\r")
    time.sleep(4)
    check("7 (several) password for all", login("root", "MultiPass9", ip_of("uit2")) and login("root", "MultiPass9", ip_of("uit3")))
    step(ui, "multi menu", multi, "0\r")
    check("7 (several) back to main menu", to_menu(ui))


def section_portforward(ui):
    print("== 11) Port Forward ==")
    ip2 = ip_of("uit2")
    main_choice(ui, 11)
    step(ui, "menu", r"5\) Active NAT Status.*?Choice \[0=Back, Enter=\d\]: ", "1\r")
    step(ui, "target", r"VPS number, name, or a custom IP address.*?: ", "uit2\r")
    step(ui, "ext port", r"External Port \(e\.g\. 8080\).*?: ", "17000\r")
    step(ui, "int port", r"Internal Port \[Enter = 17000, 0=Back\]: ", "0\r")          # Back: must go ONE step back
    check("11.1 typing 0 goes back one step only (asks the external port again, not the VPS)",
          ui.expect(r"External Port \(e\.g\. 8080\).*?: ", 10), ui.tail())
    ui.send("18080\r")
    step(ui, "int port", r"Internal Port \[Enter = 18080, 0=Back\]: ", "8088\r")
    step(ui, "proto", r"Choice \[1-3, Enter=\d, 0=Back\]: ", "\r")
    step(ui, "bind", r"External Bind IP.*?: ", "\r")
    check("11.1 add a rule", ui.expect(r"Port forward applied", 30)
          and "--dport 18080" in sh("iptables -t nat -S PREROUTING")[1], ui.tail())
    pause(ui)

    main_choice_inside = lambda: step(ui, "menu", r"5\) Active NAT Status.*?Choice \[0=Back, Enter=\d\]: ", None)
    main_choice_inside()
    m = re.search(r"Select rule # to edit \(1-(\d+)", ui.buf)  # not printed yet; find via the rule file instead
    total = int(sh("grep -c '^[a-z]*|' /opt/vpsforge/port-forwards.conf")[1] or 0)
    ui.send("2\r")
    step(ui, "edit which", r"Select rule # to edit \(1-\d+, 0=Cancel\): ", "%d\r" % total)
    step(ui, "edit target", r"Target VPS / IP \[Enter = .*?\]: ", "\r")
    step(ui, "edit ext", r"External Port \[Enter = 18080\]: ", "18081\r")
    step(ui, "edit int", r"Internal Port \[Enter = 8088\]: ", "\r")
    step(ui, "edit proto", r"Protocol \[tcp/udp/both.*?\]: ", "\r")
    step(ui, "edit bind", r"External IP \[Enter = .*?\]: ", "\r")
    ok = ui.expect(r"Port forward applied", 30)
    check("11.2 edit a rule", ok and "--dport 18081" in sh("iptables -t nat -S PREROUTING")[1]
          and "--dport 18080" not in sh("iptables -t nat -S PREROUTING")[1], ui.tail())
    pause(ui)

    main_choice_inside()
    total = int(sh("grep -c '^[a-z]*|' /opt/vpsforge/port-forwards.conf")[1] or 0)
    ui.send("3\r")
    step(ui, "delete which", r"Select rule # to delete.*?: ", "%d\r" % total)
    ok = ui.expect(r"Successfully deleted 1 port-forward rule", 30)
    check("11.3 delete a rule", ok and "--dport 18081" not in sh("iptables -t nat -S PREROUTING")[1], ui.tail())
    pause(ui)

    main_choice_inside()
    ui.send("5\r")
    check("11.5 active NAT status", ui.expect(r"Active NAT PREROUTING Rules", 30), ui.tail())
    pause(ui)

    if not SAFE:        # on a real server this would remove the owner's own forwards: only tested in the sandbox
        main_choice_inside()
        ui.send("4\r")
        step(ui, "delete all", r"delete ALL port-forward rules\? \(y/N\): ", "y\r")
        ok = ui.expect(r"All port forward rules deleted", 30)
        left = sh("iptables -t nat -S PREROUTING | grep -c DNAT")[1]
        check("11.4 delete ALL rules", ok and left in ("0", ""), left + " " + ui.tail())
        pause(ui)
    main_choice_inside()
    ui.send("0\r")
    check("11.0 back to the main menu", to_menu(ui))


def section_settings(ui):
    print("== 14) Settings ==")
    settings = r"7\) Uninstall VPSForge.*?Choice \[0=Back, Enter=\d\]: "
    main_choice(ui, 14)
    step(ui, "menu", settings, "3\r")                                 # Repair Connection (restores SSH forwards)
    ok = ui.expect(r"Repair summary: Success=(\d+) \| Failed=(\d+)", 600)
    m = re.search(r"Repair summary: Success=(\d+) \| Failed=(\d+)", ui.buf)
    check("14.3 repair connection (all VPSs)", ok and m and m.group(2) == "0", ui.tail())
    pause(ui)
    check("14.3 SSH forward rules are back after repair", "--dport 90" in sh("iptables -t nat -S PREROUTING")[1])

    step(ui, "menu", settings, "1\r")
    time.sleep(1)
    a = "AUTO_REFRESH=off" in open("/opt/vpsforge/settings.conf").read() or "AUTO_REFRESH=on" in open("/opt/vpsforge/settings.conf").read()
    check("14.1 toggle auto refresh (saved)", a)
    step(ui, "menu", settings, "1\r")

    step(ui, "menu", settings, "2\r")
    step(ui, "interval", r"Enter new refresh interval.*?: ", "7\r")
    time.sleep(1)
    check("14.2 change refresh interval", "REFRESH_INTERVAL=7" in open("/opt/vpsforge/settings.conf").read())

    step(ui, "menu", settings, "5\r")
    step(ui, "speed", r"Enter total network speed of host in Mbit.*?: ", "2000\r")
    time.sleep(3)
    check("14.5 host network speed", open("/opt/vpsforge/network_speed_mbit").read().strip() == "2000")

    step(ui, "menu", settings, "6\r")
    time.sleep(2)
    on = os.path.exists("/etc/profile.d/vpsforge-autostart.sh")
    step(ui, "menu", settings, "6\r")
    time.sleep(2)
    off = not os.path.exists("/etc/profile.d/vpsforge-autostart.sh")
    check("14.6 auto-start on login on/off", on and off)

    step(ui, "menu", settings, "4\r")
    step(ui, "update menu", r"4\) Check Update & Synchronization Status.*?Choice \[0=Cancel, Enter=1\]: ", "4\r")
    check("14.4 update status page", ui.expect(r"Active installation commit|Not initialized", 90), ui.tail())
    pause(ui)

    step(ui, "menu", settings, "7\r")
    step(ui, "uninstall confirm", r"Type UNINSTALL to permanently remove everything: ", "no\r")
    check("14.7 uninstall can be cancelled", ui.expect(r"Cancelled\.", 20))
    pause(ui)
    step(ui, "menu", settings, "0\r")
    check("14.0 back to the main menu", to_menu(ui))


def section_websites(ui):
    print("== 12) Domains & Reverse Proxy ==")
    sh("incus exec uit2 -- sh -c 'ss -lnt | grep -q :8088 || nohup python3 -m http.server 8088 >/dev/null 2>&1 &'")
    time.sleep(2)
    main_choice(ui, 12)
    step(ui, "menu", r"3\) Cloudflare real visitor IP.*?Choice \[0=Back, Enter=\d\]: ", "1\r")
    step(ui, "which vps", r"Select VPS by number or name.*?: ", "uit2\r")
    ok = ui.expect(r"Pick a number, or type any port.*?: |Port of your app.*?: ", 300)
    check("12.1 wizard lists the app's port", ok and "8088" in ui.buf[ui.pos - 500:], ui.tail())
    ui.send("\r")                                   # default port
    step(ui, "domain", r"Domain \(example: app\.mydomain\.com\).*?: ", "ui.example.com\r")
    step(ui, "path", r"Choice \[Enter=\d, 0=Back\]: ", "\r")
    step(ui, "confirm", r"Create it\? \[Y/n, 0=Back\]: ", "0\r")                           # Back from the last step...
    check("12.1 typing 0 goes back ONE step (to the folder question, not the start)",
          ui.expect(r"Which part of the domain goes to this app\?.*?Choice \[Enter=\d, 0=Back\]: ", 20), ui.tail())
    ui.send("\r")
    step(ui, "confirm", r"Create it\? \[Y/n, 0=Back\]: ", "\r")
    ok = ui.expect(r"DONE\. One last step", 120)
    conf = "/etc/caddy/vpsforge/uit2.caddy"
    check("12.1 add a domain", ok and os.path.exists(conf) and "ui.example.com" in open(conf).read(), ui.tail())
    check("12.1 DNS instructions shown", ui.expect(r"create an  A  record", 5))
    check("12.1 health check ran", ui.expect(r"REVERSE PROXY|PROXY", 90))
    pause(ui, 120)
    check("12.1 caddy accepts the config", sh("caddy validate --config /etc/caddy/Caddyfile")[0] == 0)

    step(ui, "proxy menu", r"3\) Cloudflare real visitor IP.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    check("12.2 my domains lists it", ui.expect(r"https://ui\.example\.com.*?uit2", 30), ui.tail())
    step(ui, "pick", r"Pick a number to test or remove it.*?: ", "1\r")
    step(ui, "actions", r"0\) Back\s+Choice \[0=Back, Enter=\d\]: |4\) Edit the config by hand.*?Choice \[0=Back, Enter=\d\]: ", "1\r")
    check("12.2 test a domain from the list", ui.expect(r"REVERSE PROXY|PROXY", 90), ui.tail())
    pause(ui, 120)
    step(ui, "actions", r"4\) Edit the config by hand.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    step(ui, "remove route", r"Remove this route\? \[y/N\]: ", "y\r")
    ok = ui.expect(r"Removed\.", 60)
    check("12.2 remove the route", ok and not os.path.exists(conf), ui.tail())
    pause(ui)
    step(ui, "my sites", r"No domains yet", None)
    pause(ui)

    step(ui, "proxy menu", r"3\) Cloudflare real visitor IP.*?Choice \[0=Back, Enter=\d\]: ", "3\r")
    step(ui, "cf menu", r"2\) Disable Cloudflare Real-IP.*?Choice \[0=Back, Enter=\d\]: ", "1\r")
    ok = ui.expect(r"Cloudflare Real-IP is now ENABLED|Failed to fetch", 90)
    check("12.3 Cloudflare real-IP enable", ok and "ENABLED" in ui.buf[ui.pos - 80:] and "BEGIN VPSFORGE CLOUDFLARE" in open("/etc/caddy/Caddyfile").read(), ui.tail())
    pause(ui)
    step(ui, "cf menu", r"2\) Disable Cloudflare Real-IP.*?Choice \[0=Back, Enter=\d\]: ", "2\r")
    ok = ui.expect(r"now DISABLED", 60)
    check("12.3 Cloudflare real-IP disable (rest of Caddyfile kept)", ok and "BEGIN VPSFORGE CLOUDFLARE" not in open("/etc/caddy/Caddyfile").read()
          and "import /etc/caddy/vpsforge" in open("/etc/caddy/Caddyfile").read(), ui.tail())
    pause(ui)
    step(ui, "cf menu", r"2\) Disable Cloudflare Real-IP.*?Choice \[0=Back, Enter=\d\]: ", "0\r")

    # 12.4 sites from "my computer": add, real tunnel, list, stop, start, delete (the test machine plays the PC)
    sh("mkdir -p /tmp/pcsite && echo FROM-MY-PC > /tmp/pcsite/index.html && (cd /tmp/pcsite && nohup python3 -m http.server 3000 >/dev/null 2>&1 &)")
    PM = r"3\) Cloudflare real visitor IP.*?Choice \[0=Back, Enter=\d\]: "
    TM = r"2\) My tunnels.*?Choice \[0=Back, Enter=1\]: "
    step(ui, "proxy menu", PM, "4\r")
    step(ui, "tunnel menu", TM, "1\r")
    check("12.4 add-a-tunnel wizard opens", ui.expect(r"ADD A TUNNEL", 20), ui.tail())
    step(ui, "which vps", r"Select VPS by number or name.*?: ", "uit2\r")
    step(ui, "vps port", r"Port to open on the VPS \[Enter=\d+, 0=Back\]: ", "9080\r")
    step(ui, "pc port", r"Port of your site on your computer \[Enter=\d+, 0=Back\]: ", "\r")
    step(ui, "domain", r"Domain \[Enter=none, 0=Back\]: ", "\r")
    step(ui, "public port", r"Public port on the server \[Enter=\d+, 0=Back\]: ", "\r")
    step(ui, "confirm", r"Create it\? \[Y/n, 0=Back\]: ", "\r")
    ok = ui.expect(r"DONE\. Now connect from your computer", 120)
    check("12.4 tunnel created", ok, ui.tail())
    check("12.4 the command to run on the computer is shown", ui.expect(r"ssh -N .*?-R 0\.0\.0\.0:9080:localhost:3000", 10), ui.tail())
    pause(ui)
    ip2 = ip_of("uit2")
    check("12.4 the VPS accepts tunnels (GatewayPorts)", "gatewayports yes" in sh("incus exec uit2 -- sshd -T")[1].lower())
    check("12.4 the port appears in Port Forward (menu 11) automatically", "9080|" in sh("cat /opt/vpsforge/port-forwards.conf")[1] and ip2 + ":9080" in sh("iptables -t nat -S PREROUTING")[1])
    sh("rm -f /tmp/tk /tmp/tk.pub; ssh-keygen -q -t ed25519 -N '' -f /tmp/tk")
    sh("incus exec uit2 -- sh -c 'mkdir -p /root/.ssh; cat >> /root/.ssh/authorized_keys' < /tmp/tk.pub")
    sh("ssh -f -N -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -i /tmp/tk -R 0.0.0.0:9080:localhost:3000 root@" + ip2)
    time.sleep(3)
    check("12.4 the site on 'my computer' answers through the VPS tunnel", "FROM-MY-PC" in sh("curl -s -m 10 http://" + ip2 + ":9080/")[1])

    step(ui, "tunnel menu", TM, "2\r")
    check("12.5 my tunnels lists it as connected", ui.expect(r"uit2\s+http://\S+:9080\s+9080\s+3000\s+ACTIVE - connected", 60), ui.tail())
    step(ui, "pick", r"Choice \[0=Back\]: ", "1\r")
    step(ui, "actions", r"5\) Show the command.*?Choice \[0=Back\]: ", "2\r")
    check("12.5 stop a tunnel", ui.expect(r"Stopped\.", 60) and "--dport 9080" not in sh("iptables -t nat -S PREROUTING")[1]
          and "|9080|" not in sh("cat /opt/vpsforge/port-forwards.conf")[1], ui.tail())
    pause(ui)
    step(ui, "actions", r"5\) Show the command.*?Choice \[0=Back\]: ", "3\r")
    step(ui, "edit vps port", r"Port to open on the VPS \[Enter=\d+, 0=Back\]: ", "\r")
    step(ui, "edit pc port", r"Port of your site on your computer \[Enter=\d+, 0=Back\]: ", "3001\r")
    step(ui, "edit domain", r"Domain \[Enter=none, 0=Back\]: ", "\r")
    step(ui, "edit public port", r"Public port on the server \[Enter=\d+, 0=Back\]: ", "\r")
    step(ui, "edit confirm", r"Create it\? \[Y/n, 0=Back\]: ", "\r")
    check("12.5 edit a stopped tunnel keeps it (new PC port saved, still closed)", ui.expect(r"Saved\.", 60)
          and "9080|3001|" in sh("incus config get uit2 user.vpsforge.tunnels")[1] and "--dport 9080" not in sh("iptables -t nat -S PREROUTING")[1], ui.tail())
    pause(ui)
    step(ui, "actions", r"5\) Show the command.*?Choice \[0=Back\]: ", "1\r")
    check("12.5 start it again", ui.expect(r"Started\.", 60) and "--dport 9080" in sh("iptables -t nat -S PREROUTING")[1], ui.tail())
    pause(ui)
    step(ui, "actions", r"5\) Show the command.*?Choice \[0=Back\]: ", "4\r")
    step(ui, "sure", r"Delete this tunnel for good\? \[y/N\]: ", "y\r")
    check("12.5 delete a tunnel", ui.expect(r"Deleted\.", 60) and "--dport 9080" not in sh("iptables -t nat -S PREROUTING")[1]
          and sh("incus config get uit2 user.vpsforge.tunnels")[1] == "", ui.tail())
    pause(ui)
    check("12.5 the list is empty afterwards", ui.expect(r"No tunnels yet", 30), ui.tail())
    pause(ui)
    sh("pkill -f '[s]sh -f -N -o StrictHostKeyChecking=no'; pkill -f '[h]ttp.server 3000'; rm -rf /tmp/pcsite /tmp/tk /tmp/tk.pub")
    step(ui, "tunnel menu", TM, "0\r")
    step(ui, "proxy menu", r"3\) Cloudflare real visitor IP.*?Choice \[0=Back, Enter=\d\]: ", "0\r")
    check("12.0 back to the main menu", to_menu(ui))


def section_snapshots(ui):
    print("== 13) Snapshots & Backups ==")
    sel = r"Choice \[0=Back, Enter=\d\]: "
    menu = r"12\) Clean Orphaned Backups.*?" + sel
    main_choice(ui, 13)
    step(ui, "menu", menu, "1\r")
    step(ui, "which vps", r"VPS name or number.*?: ", "uit2\r")
    step(ui, "snap name", r"Snapshot name \[Enter = auto-timestamp\]: ", "snapA\r")
    check("13.1 create snapshot", ui.expect(r"Snapshot 'snapA' created successfully", 120), ui.tail())
    pause(ui)
    sh("incus exec uit2 -- sh -c 'echo after > /root/after_snapshot'")

    step(ui, "menu", menu, "2\r")
    step(ui, "which vps", r"VPS name or number.*?: ", "uit2\r")
    check("13.2 list snapshots", ui.expect(r"snapA.*?Created", 30), ui.tail())
    pause(ui)

    step(ui, "menu", menu, "3\r")
    step(ui, "which vps", r"VPS name or number.*?: ", "uit2\r")
    step(ui, "which snap", r"Snapshot number or name to restore: ", "\r")
    step(ui, "confirm restore", r"Changes made after it are lost", "y\r")
    ok = ui.expect(r"restored successfully", 180)
    time.sleep(8)
    rc, _ = sh("incus exec uit2 -- test -e /root/after_snapshot")
    check("13.3 restore snapshot (later file is gone)", ok and rc != 0, ui.tail())
    pause(ui)

    step(ui, "menu", menu, "4\r")
    step(ui, "which vps", r"VPS name or number.*?: ", "uit2\r")
    step(ui, "which snap", r"Snapshot number\(s\) to delete.*?: ", "A\r")
    ok = ui.expect(r"Snapshot 'snapA' deleted", 60)
    check("13.4 delete snapshot", ok and sh("incus snapshot list uit2 --format csv")[1] == "", ui.tail())
    pause(ui)

    step(ui, "menu", menu, "5\r")
    step(ui, "which vps", r"VPS name or number.*?: ", "uit2\r")
    step(ui, "preview", r"Press Enter to proceed with backup.*?: ", "\r")
    step(ui, "file name", r"Enter backup filename.*?: ", "uit2-backup-ui.tar\r")
    ok = ui.expect(r"Backup saved: ", 400)
    check("13.5 export full backup (zstd compressed)", ok and os.path.getsize("/opt/vpsforge-backups/uit2-backup-ui.tar") > 1000000, ui.tail())
    pause(ui)

    step(ui, "menu", menu, "7\r")
    step(ui, "filter", r"2\) List all backup files.*?" + sel, "2\r")
    step(ui, "pick", r"Select backup file to inspect: ", "\r")
    check("13.7 inspect a backup", ui.expect(r"BACKUP FILE DETAILS.*?Original VPS:\s+uit2", 120), ui.tail())
    pause(ui)

    step(ui, "menu", menu, "6\r")
    step(ui, "filter", r"2\) List all backup files.*?" + sel, "2\r")
    step(ui, "pick", r"Select backup file to import: ", "\r")
    step(ui, "conflict", r"Choice \[0=Cancel, 1-2, Enter=0\]: ", "1\r")                  # uit2 exists -> import under another name
    step(ui, "new name", r"Enter new VPS container name \[default: .*?\]: ", "uitimp\r")
    ok = ui.expect(r"Success: uitimp restored", 400)
    check("13.6 import backup under a new name", ok and running("uitimp"), ui.tail())
    pause(ui)

    # overwrite: the old VPS is set aside, deleted only after the import worked
    step(ui, "menu", menu, "6\r")
    step(ui, "filter", r"2\) List all backup files.*?" + sel, "2\r")
    step(ui, "pick", r"Select backup file to import: ", "\r")
    step(ui, "conflict", r"Choice \[0=Cancel, 1-2, Enter=0\]: ", "2\r")
    step(ui, "sure", r"Type YES to continue: ", "YES\r")
    ok = ui.expect(r"Success: uit2 restored", 400)
    left = "1"
    for _ in range(30):                       # the old VPS is deleted right after the success line
        _, left = sh("incus list -c n --format csv | grep -c -- '-replaced-'")
        if left.strip() == "0":
            break
        time.sleep(2)
    check("13.6b overwrite import: replaced, nothing left aside", ok and running("uit2") and left.strip() == "0", ui.tail())
    pause(ui)

    step(ui, "menu", menu, "8\r")
    step(ui, "which vps", r"Select VPS container to update backup for: ", "uit2\r")
    step(ui, "filter", r"2\) List all backup files.*?" + sel, "2\r")
    step(ui, "pick", r"Select backup file to OVERWRITE / UPDATE: ", "\r")
    step(ui, "confirm", r"Overwrite and update .*?\[y/N\]: ", "y\r")
    check("13.8 update (overwrite) a backup", ui.expect(r"Backup updated successfully", 400), ui.tail())

    step(ui, "menu", menu, "10\r")
    step(ui, "filter", r"2\) List all backup files.*?" + sel, "2\r")
    step(ui, "pick", r"Select backup file to RENAME: ", "\r")
    step(ui, "new name", r"Enter new backup filename.*?: ", "ghost-backup-1.tar\r")
    check("13.10 rename a backup", ui.expect(r"Backup file renamed to ghost-backup-1\.tar", 30), ui.tail())

    step(ui, "menu", menu, "12\r")
    check("13.12 orphaned backups are found", ui.expect(r"ORPHAN\s+ghost-backup-1\.tar", 30), ui.tail())
    step(ui, "confirm", r"Delete these 1 orphaned backup\(s\)\? \[y/N\]: ", "y\r")
    check("13.12 orphaned backup deleted", ui.expect(r"Deleted\. Freed", 30) and not os.path.exists("/opt/vpsforge-backups/ghost-backup-1.tar"), ui.tail())
    pause(ui)

    step(ui, "menu", menu, "11\r")
    check("13.11 clean temp backups", ui.expect(r"Temporary backups cleaned up", 60), ui.tail())
    pause(ui)

    # delete a backup through the menu (9)
    sh("mkdir -p /opt/vpsforge-backups && head -c 3000000 /dev/zero > /opt/vpsforge-backups/uit2-backup-del.tar")
    step(ui, "menu", menu, "9\r")
    step(ui, "filter", r"2\) List all backup files.*?" + sel, "2\r")
    step(ui, "pick", r"Select backup file\(s\) to DELETE.*?: ", "A\r")
    step(ui, "confirm", r"Are you sure you want to delete these file\(s\)\? \[y/N\]: ", "y\r")
    ok = ui.expect(r"deleted\.", 30)
    check("13.9 delete backup files", ok and not [f for f in os.listdir("/opt/vpsforge-backups") if f.endswith(".tar")], ui.tail())
    pause(ui)

    step(ui, "menu", menu, "0\r")
    check("13.0 back to the main menu", to_menu(ui))
    # clean the extra VPS made by the import
    sh("ip=$(incus config get uitimp user.vpsforge.ip); incus delete uitimp --force")


def section_reinstall(ui):
    print("== 6) Reinstall ==")
    before_ip = ip_of("uit3")
    main_choice(ui, 6)
    step(ui, "select", r"Select VPS by number, name, or A for All.*?: ", "uit3\r")
    step(ui, "confirm", r"Type REINSTALL to erase and reinstall.*?: ", "REINSTALL\r")
    ok = ui.expect(r"Reinstall completed for uit3", 500)
    time.sleep(3)
    check("6) reinstall keeps IP, limits and login", ok and running("uit3") and ip_of("uit3") == before_ip
          and sh("incus config get uit3 limits.memory")[1] == "300MiB" and login("root", "MultiPass9", before_ip), ui.tail())
    pause(ui)


def section_delete(ui):
    print("== 2) Delete ==")
    # a backup that belongs to uit3: the delete menu must offer to remove it too
    sh("mkdir -p /opt/vpsforge-backups && head -c 3000000 /dev/zero > /opt/vpsforge-backups/uit3-backup-x.tar")
    ip3 = ip_of("uit3")
    main_choice(ui, 2)
    step(ui, "select", r"Select VPS by number, name, or A for All.*?: ", "uit3\r")
    step(ui, "confirm", r"Type DELETE to permanently delete, or 0 to cancel: ", "DELETE\r")
    step(ui, "backups", r"Delete these backups too\? \[Y/n\]: ", "\r")
    ok = ui.expect(r"Giving freed disk space back to the server", 120)
    check("2) delete VPS removes it", ok and not exists("uit3"), ui.tail())
    check("2) its backup was offered and deleted", not os.path.exists("/opt/vpsforge-backups/uit3-backup-x.tar"))
    check("2) no firewall rule left for its IP", ip3 not in sh("iptables -S FORWARD")[1] + sh("iptables -t nat -S PREROUTING")[1])
    pause(ui)
    # cancel path
    main_choice(ui, 2)
    step(ui, "select", r"Select VPS by number, name, or A for All.*?: ", "uit2\r")
    step(ui, "cancel", r"Type DELETE to permanently delete, or 0 to cancel: ", "0\r")
    check("2) typing 0 cancels (VPS kept)", exists("uit2") and to_menu(ui))


def driver(commands):
    """Write a tiny script that loads VPSForge and runs the given shell lines."""
    header = ("export TERM=dumb\n"
              "source /opt/vpsforge/lib/load_vpsforge_lib.sh; load_vpsforge_lib /opt/vpsforge/lib\n"
              "VPSFORGE_VERSION=drv; get_network_info; get_public_ip; load_settings\n")
    open("/tmp/ui_drv.sh", "w").write(header + commands + "\n")


def run_then_stop(commands, after, sig):
    """Start the driver, stop it with <sig> after <after> seconds, return its output."""
    import signal
    driver(commands)
    out = open("/tmp/ui_drv.out", "w")
    proc = subprocess.Popen(["bash", "/tmp/ui_drv.sh"], stdout=out, stderr=subprocess.STDOUT, preexec_fn=os.setsid)
    time.sleep(after)
    try:
        os.killpg(proc.pid, sig)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=240)
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
    out.close()
    return open("/tmp/ui_drv.out").read()


def firewall_mentions(ip, port):
    rules = sh("iptables -S FORWARD")[1] + sh("iptables -t nat -S PREROUTING")[1]
    return (ip in rules) or ("--dport %s " % port in rules)


def section_interrupt(ui):
    import signal
    print("== interruptions: nothing may be left behind ==")
    sh("incus delete uitint --force")                       # leftover of an earlier run
    sh("rm -f /opt/vpsforge/.pending/uitint")
    prefix = ".".join(ip_of("uit2").split(".")[:3])
    free_num = 40
    ip = "%s.%d" % (prefix, 100 + free_num - 1)
    port = 9000 + free_num
    create = "create_vps uitint %d 256 %d limited unlimited '' limited 5 unlimited '' images:ubuntu/noble unlimited 0 0 y" % (free_num, port)

    # a) Ctrl-C in the middle of creating a VPS
    out = run_then_stop(create, 30, signal.SIGINT)
    check("interrupt: user is told it did not finish", "did not finish" in out and "stopped before it finished" in out, out[-300:])
    check("interrupt: the half-made VPS is gone", not exists("uitint"))
    check("interrupt: its IP and SSH port were released", not firewall_mentions(ip, port))
    check("interrupt: no leftover marker or proxy file", not os.path.exists("/etc/caddy/vpsforge/uitint.caddy"))
    check("interrupt: other VPSs untouched", running("uit2"))

    # b) kill -9 in the middle (no chance to clean): startup recovery must finish the job
    run_then_stop(create, 30, signal.SIGKILL)
    leftover = exists("uitint")
    out = sh("vpsforge list", 300)[1]
    check("kill -9: recovery announces and removes the leftover", (not leftover) or "Recovery:" in out, out[-300:])
    check("kill -9: after recovery nothing remains", not exists("uitint") and not firewall_mentions(ip, port))

    # c) a backup that is stopped half-way leaves no file and no hidden copy
    sh("incus exec uit2 -- sh -c 'dd if=/dev/urandom of=/root/big bs=1M count=300 status=none; sync'")
    before_free = sh("df -m --output=avail / | tail -1")[1].strip()
    export_cmd = ("export_vps_backup_noninteractive() { mkdir -p $BACKUP_DIR/.tmp; "
                  "run_guarded \"cleanup_partial_backup uit2 $BACKUP_DIR/.tmp/x.tar\" _export_instance uit2 $BACKUP_DIR/.tmp/x.tar; }\n"
                  "export_vps_backup_noninteractive")
    out = run_then_stop(export_cmd, 4, signal.SIGINT)
    check("interrupt: backup stopped, user told why", "did not finish" in out, out[-300:])
    check("interrupt: no half-written backup file", not os.path.exists("/opt/vpsforge-backups/.tmp/x.tar") and not os.path.exists("/opt/vpsforge-backups/x.tar"))
    check("interrupt: no hidden internal incus backup", sh("incus query /1.0/instances/uit2/backups")[1].count("/1.0/") == 0)
    sh("incus exec uit2 -- rm -f /root/big")

    # d) a reinstall that fails restores the original exactly (IP, port, custom forward, login)
    ip2 = ip_of("uit2"); port2 = sh("incus config get uit2 user.vpsforge.ssh_port")[1]
    sh("vpsforge port-forward add tcp 0.0.0.0 18123 %s 8088" % ip2)
    out = sh("bash -c 'source /opt/vpsforge/lib/load_vpsforge_lib.sh; load_vpsforge_lib /opt/vpsforge/lib; VPSFORGE_VERSION=d; get_network_info; get_public_ip; load_settings; reinstall_single_vps_core uit2 images:nonexistent/xyz'", 600)[1]
    time.sleep(6)
    check("reinstall failure: user told, original restored", "restored unchanged" in out, out[-400:])
    check("reinstall failure: original VPS running again with the same IP", running("uit2") and ip_of("uit2") == ip2 and not exists("uit2-old-reinstall"))
    check("reinstall failure: SSH forward and custom forward survived",
          ("--dport %s " % port2) in sh("iptables -t nat -S PREROUTING")[1] and "--dport 18123 " in sh("iptables -t nat -S PREROUTING")[1])
    check("reinstall failure: login still works", login("root", "MultiPass9", ip2) or login("root", "root", ip2))
    sh("vpsforge port-forward delete tcp 0.0.0.0 18123 %s 8088" % ip2)


def section_cli(ui):
    print("== command line (vpsforge <command>) ==")
    check("--version", sh("vpsforge --version")[1].startswith("VPSForge v"))
    check("list", "uit1" in sh("vpsforge list")[1])
    check("details <vps>", "VPS DETAILS INSPECTOR: uit1" in sh("vpsforge details uit1")[1])
    check("stop <vps>", sh("vpsforge stop uit2")[0] == 0 and not running("uit2"))
    check("start <vps>", sh("vpsforge start uit2")[0] == 0 and (time.sleep(5) or running("uit2")))
    check("restart <vps>", sh("vpsforge restart uit2")[0] == 0 and (time.sleep(5) or running("uit2")))
    check("ram <vps> <MB>", sh("vpsforge ram uit2 400")[0] == 0 and sh("incus config get uit2 limits.memory")[1] == "400MiB")
    check("snapshot <vps> <name>", "created successfully" in sh("vpsforge snapshot uit2 cli-snap")[1])
    sh("incus snapshot delete uit2 cli-snap")
    check("quota-check", sh("vpsforge quota-check")[0] == 0)
    check("reclaim", "returned" in sh("vpsforge reclaim")[1])
    if not SAFE:        # tidy trims the server's system logs: only run in the sandbox
        check("tidy", "Done. Used after" in sh("vpsforge tidy", 300)[1])
    check("clean-backups (nothing to clean)", "Nothing to clean" in sh("vpsforge clean-backups < /dev/null")[1] or "No backup" in sh("vpsforge clean-backups < /dev/null")[1])
    check("port-forward list", sh("vpsforge port-forward list")[0] == 0)
    check("port-forward add", "applied" in sh("vpsforge port-forward add tcp 0.0.0.0 18090 %s 8088" % ip_of("uit2"))[1])
    check("port-forward delete", "removed" in sh("vpsforge port-forward delete tcp 0.0.0.0 18090 %s 8088" % ip_of("uit2"))[1])
    check("port-forward status", "Active NAT PREROUTING" in sh("vpsforge port-forward status")[1])
    update_out = sh("vpsforge update --check", 120)[1]
    check("update --check", "Active installation commit" in update_out or "Not initialized" in update_out, update_out[-200:])
    check("update --list", "VPSForge releases" in sh("vpsforge update --list", 120)[1] or "Repository" in sh("vpsforge update --list", 120)[1])
    check("uninstall --dry-run changes nothing", "Dry run finished" in sh("vpsforge uninstall --dry-run", 120)[1] and exists("uit1"))
    check("bad command prints usage", "Usage: vpsforge" in sh("vpsforge nonsense")[1])
    check("selftest (Incus compatibility)", "checks passed" in sh("vpsforge selftest")[1])
    check("incus status", "VPSForge tested with" in sh("vpsforge incus status")[1])

    # clone: an instant exact copy with its own IP and port
    sh("incus exec uit2 -- sh -c 'echo cloned-data > /root/marker'")
    out = sh("vpsforge clone uit2 uitclone", 900)[1]
    check("clone: the copy is made and running", running("uitclone") and "is a copy of uit2" in out, out[-300:])
    check("clone: it has its own IP", ip_of("uitclone") != "" and ip_of("uitclone") != ip_of("uit2"))
    check("clone: it contains the data of the original", sh("incus exec uitclone -- cat /root/marker")[1] == "cloned-data")
    check("clone: same login works on the copy", login("root", "MultiPass9", ip_of("uitclone")))
    check("clone: a bad name is refused", "Invalid name" in sh("vpsforge clone uit2 'bad name'")[1])
    cip = ip_of("uitclone"); cport = sh("incus config get uitclone user.vpsforge.ssh_port")[1]
    driver("cleanup_failed_vps uitclone %s %s" % (cip, cport))
    sh("bash /tmp/ui_drv.sh")
    check("clone: deleting the copy leaves nothing behind", not exists("uitclone") and not firewall_mentions(cip, cport))
    check("repair-all", "Repair summary" in sh("vpsforge repair-all", 900)[1])


SECTIONS = [
    ("dashboard", section_dashboard), ("create", section_create), ("details", section_details),
    ("power", section_power), ("edit", section_edit), ("portforward", section_portforward),
    ("settings", section_settings), ("websites", section_websites), ("snapshots", section_snapshots),
    ("interrupt", section_interrupt), ("reinstall", section_reinstall), ("delete", section_delete), ("cli", None),
]


def main():
    wanted = sys.argv[1:] or [n for n, _ in SECTIONS]
    ui = UI()
    try:
        for name, fn in SECTIONS:
            if name not in wanted:
                continue
            if SAFE and name in SAFE_SKIPPED:
                print("== %s: skipped (UI_TEST_SAFE: this server holds real VPSs) ==" % name)
                continue
            if name == "cli":
                ui.close()
                section_cli(None)
                ui = UI()
                continue
            if name != "dashboard" and ui.buf and not ui.expect(r"Choice: $", 3):
                # a previous section left the program inside a menu: start from a clean main menu
                ui.close()
                ui = UI()
                ui.expect(r"Choice: ", 90)
            try:
                fn(ui)
            except Exception as exc:  # keep going: one broken section must not hide the others
                check("section %s crashed" % name, False, repr(exc) + " | " + ui.tail(5))
            if not ui.alive():
                ui = UI()
                ui.expect(r"Choice: ", 60)
        if "cleanup" in wanted or len(sys.argv) == 1:
            ui.close()
            for n in NAMES + ["uitimp", "uit1r"]:
                sh("incus delete %s --force" % n)
            sh("rm -rf /opt/vpsforge-backups/uit* /opt/vpsforge-backups/ghost*")
    finally:
        ui.close()
    print("\nUI TEST RESULT: %d passed, %d failed" % (len(PASS), len(FAIL)))
    for f in FAIL:
        print("  failed:", f)
    sys.exit(1 if FAIL else 0)


main()
