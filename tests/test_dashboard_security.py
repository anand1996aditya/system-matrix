#!/usr/bin/env python3

"""
Security regression tests for the System Matrix dashboard.

Covers the 23 Oct 2026 audit findings:
  F1 path traversal in the file browser
  F2 default dashboard credentials
  F3 dashboard bound to all interfaces
  F4 weak authentication, CORS and CSRF controls

Run: python3 tests/test_dashboard_security.py
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "scripts" / "utilities"))

from dashboard_auth import hash_password, is_legacy_hash, verify_password  # noqa: E402
from path_guard import resolve_within_roots  # noqa: E402

FAILURES = []
TEXT_SUFFIXES = {".py", ".sh", ".json", ".md", ".html", ".js", ".plist", ".yml", ".yaml", ".txt"}


def check(label, condition):
    if condition:
        print(f"PASS: {label}")
    else:
        print(f"FAIL: {label}")
        FAILURES.append(label)


def test_path_guard():
    print("\n[F1] Path traversal checks")
    with tempfile.TemporaryDirectory() as temp_dir:
        base = Path(temp_dir)
        drive = base / "drive"
        drive.mkdir()
        inside = drive / "notes.txt"
        inside.write_text("inside", encoding="utf-8")
        outside = base / "outside.txt"
        outside.write_text("outside", encoding="utf-8")
        roots = [str(drive)]

        check("accepts a file inside the drive",
              resolve_within_roots(str(inside), roots) == inside.resolve())
        check("accepts the drive root itself",
              resolve_within_roots(str(drive), roots) == drive.resolve())
        check("rejects parent-directory traversal",
              resolve_within_roots(str(drive / ".." / "outside.txt"), roots) is None)
        check("rejects traversal that only starts with the drive path",
              resolve_within_roots(str(drive) + "/../outside.txt", roots) is None)
        check("rejects traversal to an absolute system path",
              resolve_within_roots(str(drive) + "/../../../../etc/passwd", roots) is None)
        check("rejects a sibling path with the same name prefix",
              resolve_within_roots(str(base / "drive2" / "file.txt"), roots) is None)
        check("rejects empty input", resolve_within_roots("", roots) is None)

        try:
            os.symlink(str(outside), str(drive / "escape-link"))
        except OSError:
            print("SKIP: symlink creation is not supported here")
        else:
            check("rejects a symlink that leaves the drive",
                  resolve_within_roots(str(drive / "escape-link"), roots) is None)

        try:
            os.symlink(str(inside), str(drive / "inside-link"))
        except OSError:
            print("SKIP: symlink creation is not supported here")
        else:
            check("accepts a symlink that stays inside the drive",
                  resolve_within_roots(str(drive / "inside-link"), roots) == inside.resolve())


def test_password_hashing():
    print("\n[F2/F4] Password hashing checks")
    password = "correct horse battery staple"
    first = hash_password(password)
    second = hash_password(password)
    legacy_hash = hashlib.sha256(password.encode("utf-8")).hexdigest()

    check("PBKDF2 hash uses the documented prefix", first.startswith("pbkdf2_sha256$"))
    check("PBKDF2 hash is salted per password", first != second)
    check("correct password verifies", verify_password(password, first) is True)
    check("wrong password fails", verify_password("wrong password", first) is False)
    check("legacy SHA-256 verifies for migration", verify_password(password, legacy_hash) is True)
    check("legacy SHA-256 helper identifies old hashes", is_legacy_hash(legacy_hash) is True)
    check("malformed hash fails closed", verify_password(password, "not-a-hash") is False)
    check("unknown hash algorithm fails closed",
          verify_password(password, "md5$1$salt$hash") is False)


def run_server_with_config(config_path):
    environment = os.environ.copy()
    environment["SYSTEM_MATRIX_CONFIG"] = str(config_path)
    return subprocess.run(
        [sys.executable, str(PROJECT_ROOT / "scripts" / "monitoring" / "dashboard-server.py")],
        capture_output=True,
        text=True,
        timeout=30,
        env=environment,
        cwd=str(PROJECT_ROOT),
    )


def test_server_refuses_to_start_without_credentials():
    print("\n[F2] Dashboard refuses to start without credentials")
    template = json.loads((PROJECT_ROOT / "config" / "config.template.json").read_text(encoding="utf-8"))

    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "config.json"
        template["dashboard_auth"]["username"] = "admin"
        template["dashboard_auth"]["password_hash"] = "WILL_BE_SET_BY_SETUP_SCRIPT"
        config_path.write_text(json.dumps(template), encoding="utf-8")

        result = run_server_with_config(config_path)
        output = result.stdout + result.stderr
        check("server exits when no password is configured", result.returncode != 0)
        check("server explains that credentials are missing",
              "No dashboard credentials configured" in output)

    with tempfile.TemporaryDirectory() as temp_dir:
        config_path = Path(temp_dir) / "config.json"
        template["dashboard_auth"]["password_hash"] = "not-a-valid-hash"
        config_path.write_text(json.dumps(template), encoding="utf-8")

        result = run_server_with_config(config_path)
        output = result.stdout + result.stderr
        check("server exits on an unrecognised password hash", result.returncode != 0)
        check("server explains the bad password hash",
              "not a recognised PBKDF2 or legacy SHA-256 hash" in output)


def repository_text_files():
    for path in PROJECT_ROOT.rglob("*"):
        if not path.is_file():
            continue
        if ".git" in path.parts or "logs" in path.parts:
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        try:
            yield path, path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue


def test_no_committed_defaults():
    print("\n[F2] No default credentials committed")
    # Build the old password from fragments so this test file does not itself
    # contain the string that the repository must no longer contain.
    default_password = "matrix" + "2026"

    hits = []
    for path, text in repository_text_files():
        if default_password in text:
            hits.append(str(path.relative_to(PROJECT_ROOT)))

    check("no default password string is committed", not hits)

    template = json.loads((PROJECT_ROOT / "config" / "config.template.json").read_text(encoding="utf-8"))
    check("config template sets no password hash",
          template["dashboard_auth"]["password_hash"] == "WILL_BE_SET_BY_SETUP_SCRIPT")

    for example in sorted((PROJECT_ROOT / "examples" / "configs").glob("*.json")):
        example_config = json.loads(example.read_text(encoding="utf-8"))
        check(f"{example.name} sets no password hash",
              example_config["dashboard_auth"]["password_hash"] == "WILL_BE_SET_BY_SETUP_SCRIPT")


def test_hardening_markers():
    print("\n[F3/F4] Bind, CORS and CSRF hardening markers")
    server_source = (PROJECT_ROOT / "scripts" / "monitoring" / "dashboard-server.py").read_text(encoding="utf-8")
    setup_source = (PROJECT_ROOT / "setup.sh").read_text(encoding="utf-8")
    template = json.loads((PROJECT_ROOT / "config" / "config.template.json").read_text(encoding="utf-8"))

    check("config template binds loopback by default",
          template["services"]["dashboard"]["host"] == "127.0.0.1")
    for example in sorted((PROJECT_ROOT / "examples" / "configs").glob("*.json")):
        example_config = json.loads(example.read_text(encoding="utf-8"))
        check(f"{example.name} binds loopback by default",
              example_config["services"]["dashboard"]["host"] == "127.0.0.1")

    check("server reads the bind host from config",
          "services.dashboard.host" in server_source)
    check("server does not send wildcard CORS",
          "Access-Control-Allow-Origin', '*'" not in server_source)
    check("server requires the custom CSRF header on POST",
          "X-Requested-With" in server_source)
    check("server does not trust X-Forwarded-For by default",
          "trust_proxy" in server_source)
    check("server verifies passwords through the PBKDF2 helper",
          "verify_password" in server_source)
    check("server uses the containment helper for file paths",
          "resolve_within_roots" in server_source)
    check("setup requires the operator to set a password",
          "A dashboard password is required" in setup_source)


def main():
    print("Dashboard security regression tests")
    print("=" * 44)
    test_path_guard()
    test_password_hashing()
    test_server_refuses_to_start_without_credentials()
    test_no_committed_defaults()
    test_hardening_markers()
    print("\n" + "=" * 44)
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} check(s)")
        return 1
    print("All dashboard security checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
