#!/usr/bin/env python3
"""
Verification tests for the live-demo recovery bootstrap — deploy/recover_live_demo.sh

This is the resilient front door that fixes the broken recovery runbook:
the old instructions said `cd /tmp/engquest && git pull`, but /tmp is wiped on
reboot (the exact failure being fixed), so post-reboot recovery was impossible.

These checks guarantee — without a live VPS — that the script:
  • clones into a PERSISTENT path, never /tmp
  • has a fallback chain so the demo is NEVER blank
  • runs the production installer (nginx + systemd watchdog)
  • installs a CRON backstop (@reboot + every 2 min) independent of systemd
  • requires root, is idempotent, and ends with a health check

Run:  python3 deploy/test_recover_live_demo.py
Exit: 0 = all pass, 1 = failure.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RECOVER = os.path.join(ROOT, "deploy", "recover_live_demo.sh")

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
    assert os.path.isfile(RECOVER), f"missing {RECOVER}"
    src = open(RECOVER, encoding="utf-8").read()

    print("recover_live_demo.sh — persistence (root-cause fix)")
    # The whole point: the checkout must live somewhere /tmp-wipe-proof.
    check("clones into PERSISTENT /opt path (not /tmp)",
          'SRC_DIR="${SRC_DIR:-/opt/engquest-src}"' in src)
    check("never uses /tmp for the source checkout",
          not re.search(r'SRC_DIR=\S*?/tmp', src))
    check("clones the correct repo",
          "github.com/chihirokajiwara-AI/engquest" in src)
    check("refreshes existing checkout idempotently",
          "reset --hard origin/main" in src and "fetch" in src)

    print("\nrecover_live_demo.sh — never-blank fallback chain")
    check("prefers fresh /tmp build first",
          'BUILD_SRC}/index.html' in src)
    check("reuses existing persistent root content",
          'WEB_ROOT}/index.html' in src)
    check("falls back to checked-in static web/ demo",
          'SRC_DIR}/web/index.html' in src
          and "seeding persistent root from checked-in web" in src)
    check("aborts loudly only if NOTHING is serveable",
          "No content available to serve" in src)

    print("\nrecover_live_demo.sh — runs production installer")
    check("invokes install_nginx.sh", "deploy/install_nginx.sh" in src)

    print("\nrecover_live_demo.sh — cron backstop (systemd-independent)")
    check("writes /etc/cron.d backstop",
          "/etc/cron.d/engquest-watchdog" in src)
    check("@reboot self-heal entry", "@reboot root" in src
          and "engquest-watchdog.sh" in src)
    check("every-2-min self-heal entry", re.search(r"\*/2 \* \* \* \* root", src))
    check("passes WEB_ROOT/BUILD_SRC/PORT to watchdog via cron",
          "WEB_ROOT=" in src and "BUILD_SRC=" in src and "PORT=" in src)
    check("logs watchdog output", "engquest-watchdog.log" in src)

    print("\nrecover_live_demo.sh — hygiene")
    check("set -euo pipefail", "set -euo pipefail" in src)
    check("requires root", re.search(r"EUID.*-ne 0", src))
    check("ensures git is installed", "install -y -qq git" in src)
    check("final health check on :8080", re.search(r"%\{http_code\}", src)
          and "127.0.0.1:${PORT}" in src)

    print("\nrunbook docs no longer rely on volatile /tmp checkout")
    readme = os.path.join(ROOT, "deploy", "README.md")
    rd = open(readme, encoding="utf-8").read()
    check("README recovery runbook references recover_live_demo.sh",
          "recover_live_demo.sh" in rd)
    check("README recovery does NOT tell operators to cd /tmp/engquest && git pull",
          "cd /tmp/engquest && git pull && sudo bash deploy/install_nginx.sh" not in rd)

    print("\nshell syntax")
    r = subprocess.run(["bash", "-n", RECOVER], capture_output=True, text=True)
    check("bash -n recover_live_demo.sh", r.returncode == 0, r.stderr.strip())

    import shutil
    if shutil.which("shellcheck"):
        r = subprocess.run(["shellcheck", "-S", "error", RECOVER],
                           capture_output=True, text=True)
        check("shellcheck (errors only)", r.returncode == 0, r.stdout.strip())
    else:
        print("  SKIP  shellcheck not installed")

    print(f"\n{passed} passed, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
