#!/usr/bin/env python3
"""VPSForge: a short-lived page for ONE VPN device, then stop.
   /<secret>/     a page with one QR code holding all the links and "Copy" buttons
   /<secret>/sub  the subscription: all the device's links (one per line), base64, for the VPN app
   vpn_once_server.py <link_file> <qr_png_file> <secret> <port> <label> <seconds>"""
import base64, html, http.server, os, sys, threading

link_path, png_path, secret, port, label, seconds = (
    sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5], int(sys.argv[6]))
with open(link_path) as f:
    link = f.read().strip()   # one link per line (Reality, Hysteria2, TLS)
with open(png_path, "rb") as f:
    qr = base64.b64encode(f.read()).decode()
for p in (link_path, png_path):
    try:
        os.remove(p)
    except OSError:
        pass
minutes = max(1, seconds // 60)
sub_body = base64.b64encode((link + chr(10)).encode())
PAGE = """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>VPN - %(label)s</title>
<style>body{font-family:system-ui,sans-serif;max-width:560px;margin:24px auto;padding:0 16px;color:#1a1a1a;background:#fff}
img{width:100%%;max-width:420px;image-rendering:pixelated;display:block;margin:16px auto;border:1px solid #ddd}
textarea{width:100%%;box-sizing:border-box;height:96px;font:12px monospace;padding:8px;border:1px solid #ccc;border-radius:8px}
button{display:block;width:100%%;margin:8px 0 16px;padding:14px;border:0;border-radius:8px;background:#88171a;color:#fff;font-weight:600;font-size:16px}
ol{line-height:1.7}.n{color:#666;font-size:14px}</style></head><body>
<h2>VPN: %(label)s</h2>
<img src="data:image/png;base64,%(qr)s" alt="QR code">
<p><b>One link with all 3 connections</b> (Reality, Hysteria2, TLS):</p>
<textarea id="s" readonly>%(sub)s</textarea>
<button onclick="cp('s',this)">Copy subscription link</button>
<p class="n">Or the 3 links themselves:</p>
<textarea id="l" readonly>%(link)s</textarea>
<button onclick="cp('l',this)">Copy the 3 links</button>
<script>function cp(i,b){var t=document.getElementById(i);t.select();t.setSelectionRange(0,99999);document.execCommand('copy');b.textContent='Copied'}</script>
<ol>
<li>Install a free app: <b>v2rayNG</b> or <b>Hiddify</b> (Android), <b>Streisand</b> or <b>V2Box</b> (iPhone), <b>v2rayN</b> or <b>Hiddify</b> (Windows).</li>
<li>Phone: in the app tap <b>+</b> &gt; <b>Scan QR code</b> and scan the code above (open this page on another screen).
It adds all 3 connections at once.<br>
On this device: tap <b>Copy the 3 links</b>, then in the app tap <b>+</b> &gt; <b>Import from clipboard</b>.<br>
Apps with subscriptions (Hiddify, v2rayN): you can add the subscription link instead.<br>
</li>
<li>The names <b>%(label)s</b>, <b>-HY2</b> and <b>-TLS</b> are filled in by themselves. Connect to the one that works best.</li>
</ol>
<p class="n">This page works for %(m)d minutes only. Keep it private: anyone with this QR code or link can use this VPN.</p>
</body></html>""" % {"label": html.escape(label), "qr": qr, "link": html.escape(link), "m": minutes,
       "sub": html.escape("http://%s:%d%s/sub" % (os.environ.get("VPN_PUBLIC_IP", ""), port, "/" + secret))}
page = PAGE.encode()
base = "/" + secret + "/"


class Handler(http.server.BaseHTTPRequestHandler):
    timeout = 10   # a browser that opens a connection and sends nothing must not hold the server

    def do_GET(self):
        if self.path in (base, base.rstrip("/")):
            body, code, ctype = page, 200, "text/html; charset=utf-8"
        elif self.path in (base + "sub", base + "sub/"):
            body, code, ctype = sub_body, 200, "text/plain; charset=utf-8"
        else:
            body, code, ctype = b"Not found", 404, "text/plain"
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def stop():
    # hard stop at the end of the lifetime, even if a connection is still open
    os._exit(0)


timer = threading.Timer(seconds, stop)
timer.daemon = True
timer.start()
http.server.HTTPServer(("0.0.0.0", port), Handler).serve_forever()
