"""Private long-running Gingerscope state runtime (NOT deployed, no market feed).

Localhost-only API + health scheduler. NO source polling, outside HTTP,
price quote service, trade commands, Discord, secrets on client, or P4 changes.
Hosting requires persistent disk/volume, TLS reverse-proxy and private auth.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hmac
import json
import os
from pathlib import Path
import secrets
from socket import getaddrinfo, AF_INET
import time

from pdiddler.backend.persistent_store import Store, iso

STATUS_PATH = "/v1/status"
HEALTH_PATH = "/healthz"

def current_time():
    return iso(datetime.now(timezone.utc))

def run_once(db_path, *, now: str | None = None, token: str | None = None) -> dict:
    """Atomically checkpoint only our private health heartbeat."""
    t = now or current_time()
    with Store(db_path) as store:
        store.prepare_health_job(now=t)
        lease = token or secrets.token_hex(16)
        if store.claim_health_job(token=lease, now=t):
            if not store.finish_health_job(token=lease, now=t):
                raise RuntimeError("HEALTH_LEASE_LOST")
        return store.safe_status(now=t)

def make_handler(db_path: str | Path, read_token: str):
    # Never embed the upstream API key here: it is NOT a reader credential.
    if type(read_token) is not str or len(read_token) < 32 or not read_token.isascii():
        raise ValueError("PRIVATE_READ_TOKEN_REQUIRED")
    db_path = str(db_path)

    class Handler(BaseHTTPRequestHandler):
        server_version = "GingerscopePrivateStatus/1"
        sys_version = ""

        def log_message(self, *_args):
            # No Authorization / query strings / IPs in logs.
            pass

        def _respond(self, code, payload):
            body = json.dumps(payload, sort_keys=True).encode("ascii")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path == HEALTH_PATH:
                self._respond(200, {"status":"ALIVE_NOT_MARKET_READY"})
                return
            if self.path != STATUS_PATH:
                self._respond(404, {"error":"NOT_FOUND"})
                return
            actual = self.headers.get("Authorization")
            expected = "Bearer " + read_token
            if type(actual) is not str or not hmac.compare_digest(actual,expected):
                self._respond(401, {"error":"PRIVATE_AUTH_REQUIRED"})
                return
            with Store(db_path) as store:
                self._respond(200, store.safe_status(now=current_time()))

        def do_POST(self):
            self._respond(405, {"error":"READ_ONLY_API"})

        def do_PUT(self):
            self._respond(405, {"error":"READ_ONLY_API"})

        def do_DELETE(self):
            self._respond(405, {"error":"READ_ONLY_API"})

    return Handler

def serve_local(db_path, *, port: int, read_token: str):
    if type(port) is not int or not 1024 <= port <= 65535:
        raise ValueError("PORT_NOT_ALLOWED")
    handler = make_handler(db_path, read_token)
    # Loopback only. No direct public interface and no TLS termination here.
    with ThreadingHTTPServer(("127.0.0.1",port),handler) as server:
        server.daemon_threads = True
        server.serve_forever(poll_interval=1)

def main(argv=None):
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="command", required=True)
    for cmd in ("init","once","serve"):
        p = sub.add_parser(cmd)
        p.add_argument("--db",required=True)
        if cmd == "serve":
            p.add_argument("--port",type=int,default=8787)
    args = ap.parse_args(argv)
    dbpath = Path(args.db)
    if not dbpath.parent.is_dir():
        raise SystemExit("DB_PARENT_DIRECTORY_MUST_EXIST_AND_BE_PERSISTENT")
    if args.command == "init":
        with Store(dbpath) as store:
            status = store.safe_status(now=current_time())
    elif args.command == "once":
        status = run_once(dbpath)
    else:
        token = os.environ.get("GINGERSCOPE_BACKEND_READ_TOKEN","")
        serve_local(dbpath,port=args.port,read_token=token)
        return 0
    print(json.dumps(status,sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
