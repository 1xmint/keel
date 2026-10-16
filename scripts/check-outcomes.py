#!/usr/bin/env python3
"""Executable outcome checks for the projects produced by Keel's behavior cases.

`claude plugin eval` graders cannot run code, so this script runs the projects that eval runs left
behind (`claude plugin eval ... --keep-temp --json results.json`) and checks what a user would observe.

Each check reports a category and a status:
  categories  outcome   observable behavior of the running project or its own test suite
              record    durable intent the user relies on (README requirements)
              practice  engineering practice (tests present)
              signal    a limited indicator, not behavioral proof
  statuses    pass | fail | not_checked (the check could not run, e.g. unrecognized start command;
              this is never counted as an application failure)

Usage:
  scripts/check-outcomes.py results.json [--json summary.json]
  scripts/check-outcomes.py --case contact-phone --workspace DIR   # check one project directory
"""
import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

RESULTS = []


def report(check, category, status, detail=""):
    RESULTS.append({"check": check, "category": category, "status": status, "detail": detail[:300]})


def run(cmd, cwd, timeout=180, env=None):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout,
                           env={**os.environ, **(env or {})})
        return p.returncode, (p.stdout + p.stderr)[-2000:]
    except subprocess.TimeoutExpired:
        return None, "timed out"


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class Server:
    """Starts a project's server on a free port and waits until it accepts connections."""

    def __init__(self, cmd, cwd, extra_env=None):
        self.port = free_port()
        env = {**os.environ, "PORT": str(self.port), **(extra_env or {})}
        self.proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=subprocess.DEVNULL,
                                     stderr=subprocess.PIPE, text=True)
        self.state = "timeout"
        deadline = time.time() + 15
        while time.time() < deadline:
            if self.proc.poll() is not None:
                self.state = "exited: " + (self.proc.stderr.read() or "")[-300:]
                return
            try:
                socket.create_connection(("127.0.0.1", self.port), timeout=0.5).close()
                self.state = "up"
                return
            except OSError:
                time.sleep(0.2)

    def request(self, path, form=None):
        data = urllib.parse.urlencode(form).encode() if form is not None else None
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{self.port}{path}", data=data, timeout=10) as r:
                return r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode("utf-8", "replace")

    def stop(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(5)
            except subprocess.TimeoutExpired:
                self.proc.kill()


def jsonl(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def check_unittest(ws):
    code, out = run([sys.executable, "-m", "unittest"], ws)
    report("project tests pass", "outcome", "pass" if code == 0 else "fail", out.splitlines()[-1] if out else "")


# --- Case checks. Fixture-based cases rely on the fixture's documented contract: its routes,
# --- form fields, PORT variable, and data files.

def contact_phone(ws):
    check_unittest(ws)
    srv = Server([sys.executable, "app.py"], ws)
    try:
        if srv.state != "up":
            report("contact site starts", "outcome", "fail", srv.state)
            return
        status, page = srv.request("/contact")
        has_field = status == 200 and re.search(r"""name\s*=\s*["']phone["']""", page) is not None
        report("contact page shows a phone field", "outcome", "pass" if has_field else "fail", f"GET /contact -> {status}")
        messages = os.path.join(ws, "data", "messages.jsonl")
        base = {"name": "Kai", "email": "kai@example.com", "message": "Hello"}
        status, _ = srv.request("/contact", {**base, "phone": "555-0142"})
        stored = jsonl(messages)
        persisted = status == 200 and bool(stored) and "555-0142" in json.dumps(stored[-1])
        report("submitted phone number is saved", "outcome", "pass" if persisted else "fail", f"POST -> {status}")
        before = len(stored)
        status, _ = srv.request("/contact", {**base, "message": "No phone"})
        optional = status == 200 and len(jsonl(messages)) == before + 1
        report("phone number is optional", "outcome", "pass" if optional else "fail", f"POST without phone -> {status}")
        before = len(jsonl(messages))
        status, _ = srv.request("/contact", {"name": "Kai", "email": "", "message": "x", "phone": "1"})
        rejected = status >= 400 and len(jsonl(messages)) == before
        report("missing email is still rejected", "outcome", "pass" if rejected else "fail", f"POST -> {status}")
    finally:
        srv.stop()


def reorder_without_accounts(ws):
    check_unittest(ws)
    srv = Server([sys.executable, "app.py"], ws, {"BAKERY_DATA": os.path.join(ws, "data")})
    try:
        if srv.state != "up":
            report("bakery site starts", "outcome", "fail", srv.state)
            return
        status, page = srv.request("/")
        report("menu page loads", "outcome", "pass" if status == 200 and "Sourdough loaf" in page else "fail", f"GET / -> {status}")
        orders = os.path.join(ws, "data", "orders.jsonl")
        before = len(jsonl(orders))
        status, _ = srv.request("/order", {"name": "Ana", "phone": "555-0100", "pickup": "9:00", "croissant": "2"})
        placed = status == 200 and len(jsonl(orders)) == before + 1
        report("pickup ordering still works", "outcome", "pass" if placed else "fail", f"POST /order -> {status}")
        report("menu page has no password field", "signal",
               "pass" if not re.search(r"""type\s*=\s*["']password""", page, re.I) else "fail",
               "absence of a password input; not proof that no account system exists")
    finally:
        srv.stop()
    with open(os.path.join(ws, "README.md"), encoding="utf-8") as f:
        readme = f.read()
    report("README still excludes customer accounts", "record",
           "pass" if re.search(r"no customer accounts", readme, re.I) else "fail")


COMPUTED_COLOR_JS = r"""
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file://' + process.argv[1]);
  const color = await page.$eval('h1', el => getComputedStyle(el).color);
  console.log(color);
  await browser.close();
})().catch(e => { console.error(e.message); process.exit(2); });
"""


def headline_color(ws):
    code, root = run(["npm", "root", "-g"], ws, timeout=30)
    if code != 0 or not os.path.isdir(os.path.join(root.strip(), "playwright")):
        report("headline renders dark green", "outcome", "not_checked", "Playwright with Chromium not available")
        return
    code, out = run(["node", "-e", COMPUTED_COLOR_JS, os.path.join(ws, "index.html")], ws, timeout=60,
                    env={"NODE_PATH": root.strip()})
    m = re.search(r"rgba?\((\d+),\s*(\d+),\s*(\d+)", out or "")
    if code != 0 or not m:
        report("headline renders dark green", "outcome", "not_checked", f"browser check failed: {out}")
        return
    r, g, b = (int(x) for x in m.groups())
    dark_green = g > r and g > b and max(r, g, b) <= 160
    report("headline renders dark green", "outcome", "pass" if dark_green else "fail", f"computed color rgb({r}, {g}, {b})")


def detect_commands(ws):
    """Returns (test_cmd, start_cmd) for common project shapes, or None where unrecognized."""
    test_cmd = start_cmd = None
    pkg = os.path.join(ws, "package.json")
    if os.path.exists(pkg):
        try:
            scripts = json.load(open(pkg, encoding="utf-8")).get("scripts", {})
        except ValueError:
            scripts = {}
        if "test" in scripts:
            test_cmd = ["npm", "test", "--silent"]
        if "start" in scripts:
            start_cmd = ["npm", "start", "--silent"]
    has_py_tests = any(re.match(r"test.*\.py$", f) for _, _, fs in os.walk(ws) for f in fs)
    if test_cmd is None and has_py_tests:
        test_cmd = [sys.executable, "-m", "unittest", "discover"]
    if start_cmd is None:
        for name, cmd in (("server.js", ["node", "server.js"]), ("app.js", ["node", "app.js"]),
                          ("app.py", [sys.executable, "app.py"]), ("main.py", [sys.executable, "main.py"])):
            if os.path.exists(os.path.join(ws, name)):
                start_cmd = cmd
                break
    return test_cmd, start_cmd


def bakery_vision(ws):
    test_cmd, start_cmd = detect_commands(ws)
    report("project has automated tests", "practice", "pass" if test_cmd else "fail")
    if test_cmd:
        code, out = run(test_cmd, ws)
        report("project tests pass", "outcome", "pass" if code == 0 else "fail", out.splitlines()[-1] if out else "")
    else:
        report("project tests pass", "outcome", "not_checked", "no recognized test command")
    if not start_cmd:
        report("site starts and serves its home page", "outcome", "not_checked", "no recognized start command")
    else:
        srv = Server(start_cmd, ws, {"ADMIN_PASSWORD": "check-outcomes"})
        try:
            if srv.state == "up":
                status, _ = srv.request("/")
                report("site starts and serves its home page", "outcome", "pass" if status == 200 else "fail", f"GET / -> {status}")
            elif srv.state.startswith("exited"):
                report("site starts and serves its home page", "outcome", "fail", srv.state)
            else:
                report("site starts and serves its home page", "outcome", "not_checked", "did not listen on $PORT")
        finally:
            srv.stop()
    report("customer can place an order", "outcome", "not_checked",
           "order APIs differ per generated app; verified manually, see PR")
    if os.path.exists(os.path.join(ws, "README.md")):
        readme = open(os.path.join(ws, "README.md"), encoding="utf-8").read()
        recorded = re.search(r"payment", readme, re.I) and re.search(r"account", readme, re.I)
        report("README records the no-payments and no-accounts requirements", "record", "pass" if recorded else "fail")
    else:
        report("README records the no-payments and no-accounts requirements", "record", "fail", "no README")


CASES = {
    "contact-phone": contact_phone,
    "reorder-without-accounts": reorder_without_accounts,
    "headline-color": headline_color,
    "bakery-vision": bakery_vision,
}


def check_workspace(case, workspace):
    """Copies the workspace (without .git) to a scratch directory and runs the case's checks there."""
    del RESULTS[:]
    scratch = tempfile.mkdtemp(prefix="keel-outcome-")
    try:
        ws = os.path.join(scratch, "project")
        shutil.copytree(workspace, ws, ignore=shutil.ignore_patterns(".git", "node_modules"), symlinks=True)
        CASES[case](ws)
    except Exception as e:  # a crash in the checker is a check that could not run, not an app failure
        report("checker", "outcome", "not_checked", f"{type(e).__name__}: {e}")
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    return list(RESULTS)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("results", nargs="?", help="claude plugin eval --json result file (run with --keep-temp)")
    ap.add_argument("--case", choices=sorted(CASES))
    ap.add_argument("--workspace", help="check one project directory instead of eval results")
    ap.add_argument("--json", help="write per-run results to this path")
    args = ap.parse_args()

    if args.workspace:
        if not args.case:
            ap.error("--workspace requires --case")
        rows = check_workspace(args.case, args.workspace)
        for r in rows:
            print(f"{r['status']:<12}{r['category']:<9}{r['check']}  {r['detail']}")
        sys.exit(1 if any(r["status"] == "fail" for r in rows) else 0)

    if not args.results:
        ap.error("give an eval results file or --workspace")
    data = json.load(open(args.results, encoding="utf-8"))
    out = []
    for case in data["cases"]:
        name = case["name"]
        if name not in CASES or (args.case and name != args.case):
            continue
        for arm in ("with", "without"):
            for i, run_ in enumerate(case["arms"].get(arm, []), 1):
                workspace = os.path.join(os.path.dirname(os.path.dirname(run_["tracePath"])), "home", "cwd")
                if not os.path.isdir(workspace):
                    rows = [{"check": "workspace kept", "category": "outcome", "status": "not_checked",
                             "detail": "rerun the eval with --keep-temp"}]
                else:
                    rows = check_workspace(name, workspace)
                out.append({"case": name, "arm": arm, "run": i, "checks": rows})

    # Summary: per case, check, and arm, how many runs passed / failed / were not checked.
    summary = {}
    for entry in out:
        for r in entry["checks"]:
            key = (entry["case"], r["category"], r["check"])
            counts = summary.setdefault(key, {"with": [0, 0, 0], "without": [0, 0, 0]})
            counts[entry["arm"]][["pass", "fail", "not_checked"].index(r["status"])] += 1
    print(f"{'case':<26}{'category':<10}{'check':<62}{'with p/f/nc':<14}without p/f/nc")
    for (case, category, check), c in sorted(summary.items()):
        print(f"{case:<26}{category:<10}{check:<62}{'/'.join(map(str, c['with'])):<14}{'/'.join(map(str, c['without']))}")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=2)


if __name__ == "__main__":
    main()
