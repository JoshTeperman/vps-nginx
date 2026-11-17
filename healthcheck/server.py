#!/usr/bin/env python3
"""Minimal health-check HTTP server, bound to localhost and fronted by nginx."""
import json
import os
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("HEALTHCHECK_HOST", "127.0.0.1")
PORT = int(os.environ.get("HEALTHCHECK_PORT", "8081"))
STARTED = time.time()


class Handler(BaseHTTPRequestHandler):
    server_version = "healthcheck/1.0"

    def do_GET(self):
        if self.path.split("?", 1)[0] != "/health":
            return self._send(404, {"status": "not_found"})
        self._send(200, {
            "status": "ok",
            "host": socket.gethostname(),
            "uptime_s": round(time.time() - STARTED, 1),
            "client": self.headers.get("X-Real-IP", self.client_address[0]),
        })

    do_HEAD = do_GET

    def _send(self, code, body):
        data = (json.dumps(body) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)


if __name__ == "__main__":
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
