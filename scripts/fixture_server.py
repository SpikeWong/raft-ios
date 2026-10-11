#!/usr/bin/env python3
"""Local-only WebView acceptance fixture; not a Raft server."""
from http.server import BaseHTTPRequestHandler, HTTPServer

HTML = b'''<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:18px system-ui;margin:24px;background:#fafafa}input{font:18px system-ui;width:90%;padding:12px}a{display:block;margin:20px 0}button{font:18px system-ui}</style>
<h1>Raft fixture</h1><p>Controlled shell test page</p>
<label for="draft">Draft</label><input id="draft" aria-label="Draft" placeholder="Draft">
<a href="/thread">Open thread</a><a href="/error">HTTP error</a>
<a href="/thread" target="_blank">Open same-origin window</a>
<script>const el=document.getElementById('draft');el.value=localStorage.getItem('draft')||'';
el.addEventListener('input',()=>localStorage.setItem('draft',el.value));</script>'''

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
