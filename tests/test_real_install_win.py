#!/usr/bin/env python3
"""
REAL install verification for Windows — no self-test mocking.

Unlike test_e2e.py (which runs with CAG_SELFTEST=1 and skips every real side
effect), this exercises the ACTUAL Windows install path that a brand-new user
hits: a real `npm install -g @anthropic-ai/claude-code`, then checks that the
`claude` command is resolvable afterward (the make-or-break "fresh shell can
find it" requirement).

It needs the npm registry (network) but NO API key — tool installs are
key-free. It only runs on Windows; on other OSes it is a no-op skip so the
suite stays green in local/macOS runs. Intended to run on GitHub Actions'
windows-latest runner, which ships Node/npm preinstalled.

Usage:
  python tests/test_real_install_win.py
"""
import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

# Import server.py WITHOUT CAG_SELFTEST so the real install code runs.
os.environ.pop("CAG_SELFTEST", None)
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import server  # noqa: E402

IS_WIN = sys.platform.startswith("win")

# The install logs contain Chinese; a Windows console defaults to cp1252/cp936
# and a raw print() would crash with UnicodeEncodeError. Match what server.py's
# main() does so this shim can print progress safely.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def _log(**kw):
    """Minimal sse() shim — print so CI logs show progress."""
    if kw.get("log"):
        try:
            print("   ", kw["log"])
        except Exception:
            pass


@unittest.skipUnless(IS_WIN, "real Windows install path only")
class RealWindowsInstall(unittest.TestCase):
    def test_claude_npm_install_and_path(self):
        # Node/npm must be present on the runner (windows-latest ships them).
        self.assertTrue(server._which("npm"), "npm not found on runner")

        # Run the REAL Windows Claude install branch.
        server._install_claude(_log)

        # After install + _refresh_windows_path(), the shim must resolve in this
        # process AND a freshly spawned shell.
        server._refresh_windows_path()
        self.assertIsNotNone(shutil.which("claude"),
                             "claude.cmd not on PATH after install")

        # A brand-new subprocess (fresh PATH from registry merge) must run it.
        r = subprocess.run(["claude", "--version"], capture_output=True,
                           text=True, timeout=120, shell=True)
        print("    claude --version:", (r.stdout or r.stderr).strip()[:120])
        self.assertEqual(r.returncode, 0, "claude --version failed in fresh shell")


if __name__ == "__main__":
    unittest.main(verbosity=2)
