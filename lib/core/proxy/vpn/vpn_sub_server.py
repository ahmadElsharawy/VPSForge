#!/usr/bin/env python3
"""VPSForge: the permanent web server of one VPN (systemd service vpsforge-vpnsub-<port>).
   /s/<token>     a device's subscription: all its links (Reality, Hysteria2, TLS), base64, for the VPN app,
                  with the days and GB left (in the names and in the "subscription-userinfo" header)
   /<secret>/     a short-lived page with one QR code and "Copy" buttons (made by vpn_share_link)
   /<secret>/sub  the subscription of that page's device, while the page lives
   vpn_sub_server.py <folder> <port> [tls_cert_dir]
Files are read on every request, so a change made by VPSForge shows at once. Nothing else is served.
With a tls_cert_dir that holds cert.pem + key.pem, it serves HTTPS (so the subscription token is not
sent in clear over the network); without one it serves plain HTTP."""
import base64, html, http.server, os, re, shutil, sys, time

root, port = sys.argv[1], int(sys.argv[2])
HEX = re.compile(r"^[0-9a-f]{16,64}$")   # tokens and page secrets: never a path


def read(path, mode="r"):
    try:
        with open(path, mode) as f:
            return f.read()
    except OSError:
        return None


def subscription(token):
    """(info, label, links) of a device, or None."""
    text = read(os.path.join(root, "subs", token)) if HEX.match(token) else None
    if not text:
        return None
    lines = text.splitlines()
    if len(lines) < 3:
        return None
    return lines[0], lines[1], "\n".join(lines[2:]) + "\n"


def page_dir(secret):
    """Folder of a living page, or None. An expired page is deleted here."""
    if not HEX.match(secret):
        return None
    d = os.path.join(root, "pages", secret)
    expires = read(os.path.join(d, "expires"))
    if expires is None:
        return None
    if not expires.strip().isdigit() or time.time() > int(expires.strip()):
        shutil.rmtree(d, ignore_errors=True)
        return None
    return d


def drop_old_pages():
    try:
        names = os.listdir(os.path.join(root, "pages"))
    except OSError:
        return
    for name in names:
        page_dir(name)


PAGE = """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>VPN - %(label)s</title>
<style>body{font-family:system-ui,sans-serif;max-width:560px;margin:24px auto;padding:0 16px;color:#1a1a1a;background:#fff}
img{width:100%%;max-width:420px;image-rendering:pixelated;display:block;margin:16px auto;border:1px solid #ddd}
textarea{width:100%%;box-sizing:border-box;height:96px;font:12px monospace;padding:8px;border:1px solid #ccc;border-radius:8px}
button{display:block;width:100%%;margin:8px 0 16px;padding:14px;border:0;border-radius:8px;background:#88171a;color:#fff;font-weight:600;font-size:16px}
ol{line-height:1.7}.n{color:#666;font-size:14px}</style></head><body>
<h2>VPN: %(label)s</h2>
<img src="data:image/png;base64,%(qr)s" alt="QR code">
<p><b>Subscription link</b> (all 3 connections; it keeps working, and <b>Update</b> in the app shows the days and GB left):</p>
<textarea id="s" readonly>%(sub)s</textarea>
<button onclick="cp('s',this)">Copy subscription link</button>
<p class="n">Or the 3 links themselves:</p>
<textarea id="l" readonly>%(links)s</textarea>
<button onclick="cp('l',this)">Copy the 3 links</button>
<script>function cp(i,b){var t=document.getElementById(i);t.select();t.setSelectionRange(0,99999);document.execCommand('copy');b.textContent='Copied'}</script>
<ol>
<li>Install a free app: <b>v2rayNG</b> or <b>Hiddify</b> (Android), <b>Streisand</b> or <b>V2Box</b> (iPhone), <b>v2rayN</b> or <b>Hiddify</b> (Windows).</li>
<li>Best: copy the <b>subscription link</b>, then in the app add it as a subscription
(v2rayNG: menu &gt; <b>Subscription group setting</b> &gt; <b>+</b>, paste it as the URL, then <b>Update subscription</b>).<br>
Or scan the QR code (<b>+</b> &gt; <b>Scan QR code</b>) or copy the 3 links (<b>+</b> &gt; <b>Import from clipboard</b>).</li>
<li>The names <b>%(label)s</b> + <b>-REALITY</b>, <b>-HY2</b> and <b>-TLS</b> are filled in by themselves. Connect to the one that works best.</li>
</ol>
<p class="n">This page works for a few minutes only; the subscription link keeps working. Keep both private: anyone with them can use this VPN.</p>
</body></html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    timeout = 10   # a client that opens a connection and sends nothing must not hold a thread

    def reply(self, code, body, ctype, extra=()):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def send_subscription(self, token):
        sub = subscription(token)
        if sub is None:
            return self.reply(404, b"Not found", "text/plain")
        info, label, links = sub
        title = "base64:" + base64.b64encode(label.encode()).decode()
        self.reply(200, base64.b64encode(links.encode()), "text/plain; charset=utf-8", (
            ("subscription-userinfo", info),
            ("profile-update-interval", os.environ.get("VPN_SUB_UPDATE_HOURS", "6")),
            ("profile-title", title),
            ("content-disposition", 'attachment; filename="%s"' % re.sub(r"[^A-Za-z0-9._-]", "_", label)),
        ))

    def do_GET(self):
        drop_old_pages()
        parts = [p for p in self.path.split("?", 1)[0].split("/") if p]   # apps may add ?flag=...
        if len(parts) == 2 and parts[0] == "s":
            return self.send_subscription(parts[1])
        if parts and len(parts) <= 2:
            d = page_dir(parts[0])
            token = (read(os.path.join(d, "token")) or "").strip() if d else ""
            if d and token and len(parts) == 2 and parts[1] == "sub":
                return self.send_subscription(token)
            sub = subscription(token) if d and token else None
            png = read(os.path.join(d, "qr.png"), "rb") if sub else None
            if sub and png and len(parts) == 1:
                body = PAGE % {"label": html.escape(sub[1]), "qr": base64.b64encode(png).decode(),
                               "links": html.escape(sub[2]),
                               "sub": html.escape((read(os.path.join(d, "url")) or "").strip())}
                return self.reply(200, body.encode(), "text/html; charset=utf-8")
        self.reply(404, b"Not found", "text/plain")

    def log_message(self, *args):
        pass


server = http.server.ThreadingHTTPServer(("0.0.0.0", port), Handler)
server.daemon_threads = True
# Optional HTTPS: wrap the socket in TLS when a cert dir with cert.pem + key.pem is given, so the
# subscription token never travels in clear. The cert is self-signed (IP-only install), so a VPN app
# may ask to allow it once.
cert_dir = sys.argv[3] if len(sys.argv) > 3 else ""
if cert_dir:
    import ssl
    cert, key = os.path.join(cert_dir, "cert.pem"), os.path.join(cert_dir, "key.pem")
    if os.path.exists(cert) and os.path.exists(key):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(cert, key)
        server.socket = ctx.wrap_socket(server.socket, server_side=True)
server.serve_forever()
