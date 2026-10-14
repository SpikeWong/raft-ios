#!/usr/bin/env python3
"""Local-only WebView acceptance fixture; not a Raft server."""
from http.server import BaseHTTPRequestHandler, HTTPServer

HTML = b'''<!doctype html><html lang="zh-Hans"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<style>body{font:18px system-ui;margin:24px;background:#fafafa}input{font:18px system-ui;width:90%;padding:12px}a{display:block;margin:20px 0}.fixture-row{display:flex;align-items:center;gap:10px;padding:12px;width:100%;text-align:left;font:600 16px system-ui;border:2px solid transparent;background:transparent;color:inherit}.fixture-row:hover{border-color:black;background:#fe7da8}.fixture-heading{margin-top:20px;font:700 12px system-ui;color:#666;text-transform:uppercase}</style>
<h1>Raft fixture</h1><p>Controlled shell test page</p>
<label for="draft">Draft</label><input id="draft" aria-label="Draft" placeholder="Draft">
<button id="settings" onclick="history.pushState({},'', '/s/fixture/settings');renderSettings()">Settings</button>
<a href="/thread">Open thread</a><a href="/error">HTTP error</a>
<a href="/thread" target="_blank">Open same-origin window</a>
<div id="settings-target"></div>
<script>const el=document.getElementById('draft');el.value=localStorage.getItem('draft')||'';
el.addEventListener('input',()=>localStorage.setItem('draft',el.value));
function renderSettings(){document.getElementById('settings-target').innerHTML=location.pathname.endsWith('/settings')?'<div data-testid="settings-sidebar-list"><div><div class="fixture-heading">Account</div><button class="fixture-row">Profile</button></div></div>':'';}
renderSettings();</script></html>'''


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        code = 503 if self.path == '/error' else 200
        self.send_response(code)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(HTML)

    def log_message(self, *args):
        pass

if __name__ == '__main__':
    HTTPServer(('127.0.0.1', 8767), Handler).serve_forever()
