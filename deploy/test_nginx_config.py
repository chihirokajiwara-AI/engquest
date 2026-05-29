#!/usr/bin/env python3
"""
Verification tests for P0.3 — nginx deployment package.

Validates that the committed nginx config + install script satisfy every
requirement of the task WITHOUT needing the live VPS:

  • serves /tmp/engquest/build/web
  • gzip enabled
  • cache headers (immutable for hashed assets, no-cache for index/sw)
  • SPA fallback
  • auto-restart on reboot (systemd enable)
  • idempotent + validated install (nginx -t, health check)

Also runs `bash -n` on the install script and, if `nginx` is available,
`nginx -t` against the config in a sandboxed prefix.

Run:  python3 deploy/test_nginx_config.py
Exit: 0 = all pass, 1 = failure.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONF = os.path.join(ROOT, "deploy", "nginx", "engquest.conf")
INSTALL = os.path.join(ROOT, "deploy", "install_nginx.sh")

passed = 0
failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}  {detail}")


def main():
    assert os.path.isfile(CONF), f"missing {CONF}"
    assert os.path.isfile(INSTALL), f"missing {INSTALL}"
    conf = open(CONF, encoding="utf-8").read()
    inst = open(INSTALL, encoding="utf-8").read()

    print("nginx config — requirements")
    check("listens on :8080", re.search(r"listen\s+8080", conf))
    check("serves /tmp/engquest/build/web", "/tmp/engquest/build/web" in conf)
    check("gzip on", re.search(r"\bgzip\s+on\b", conf))
    check("gzip_static (precompressed)", "gzip_static on" in conf)
    check("gzip covers js", "application/javascript" in conf)
    check("gzip covers wasm", "application/wasm" in conf)
    check("immutable cache for hashed js/css/wasm",
          re.search(r"js\|css\|wasm", conf) and "immutable" in conf)
    check("index.html no-cache", re.search(r"location = /index\.html", conf)
          and "no-cache" in conf)
    check("service worker no-cache", "flutter_service_worker.js" in conf
          and "sw.js" in conf)
    check("long cache for mp3/svg/img",
          re.search(r"mp3\|svg", conf) and "max-age=2592000" in conf)
    check("CORS on audio/static", 'Access-Control-Allow-Origin "*"' in conf)
    check("SPA fallback to index.html", "try_files $uri $uri/ /index.html" in conf)
    check("server_tokens off", "server_tokens off" in conf)
    check("wasm mime mapping", re.search(r"application/wasm\s+wasm", conf))

    print("\ninstall script — requirements")
    check("set -euo pipefail", "set -euo pipefail" in inst)
    check("installs nginx if missing", "apt-get install -y -qq nginx" in inst)
    check("kills lingering :8080 (python http.server)",
          "fuser" in inst and "${PORT}/tcp" in inst and 'PORT="8080"' in inst)
    check("validates config (nginx -t) before reload", "nginx -t" in inst)
    check("enables on boot (survives reboot)", "systemctl enable nginx" in inst)
    check("restarts nginx", "systemctl restart nginx" in inst)
    check("pre-compresses assets (.gz)", re.search(r"gzip -9 -k -f", inst))
    check("post-deploy health check", re.search(r"%\{http_code\}", inst))
    check("requires root", re.search(r"EUID.*-ne 0", inst))
    check("disables default site", "sites-enabled/default" in inst)
    check("symlinks into sites-enabled", "sites-enabled/engquest.conf" in inst)

    print("\nshell syntax")
    r = subprocess.run(["bash", "-n", INSTALL], capture_output=True, text=True)
    check("bash -n install_nginx.sh", r.returncode == 0, r.stderr.strip())

    if shutil.which("shellcheck"):
        r = subprocess.run(["shellcheck", "-S", "error", INSTALL],
                           capture_output=True, text=True)
        check("shellcheck (errors only)", r.returncode == 0, r.stdout.strip())
    else:
        print("  SKIP  shellcheck not installed")

    print("\nnginx -t (sandboxed)")
    if shutil.which("nginx"):
        tmp = tempfile.mkdtemp(prefix="engquest-nginx-")
        try:
            os.makedirs(os.path.join(tmp, "logs"), exist_ok=True)
            os.makedirs("/tmp/engquest/build/web", exist_ok=True)
            wrapper = os.path.join(tmp, "nginx.conf")
            with open(wrapper, "w") as f:
                f.write(
                    f"events {{}}\n"
                    f"http {{\n"
                    f"  access_log {tmp}/logs/a.log;\n"
                    f"  error_log {tmp}/logs/e.log;\n"
                    f"  include {CONF};\n"
                    f"}}\n"
                )
            r = subprocess.run(["nginx", "-t", "-c", wrapper, "-p", tmp],
                               capture_output=True, text=True)
            ok = r.returncode == 0
            check("nginx -t passes", ok, (r.stderr or r.stdout).strip())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    else:
        print("  SKIP  nginx binary not available in CI container")

    print(f"\n{passed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
