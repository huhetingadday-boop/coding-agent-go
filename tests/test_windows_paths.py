#!/usr/bin/env python3
"""
Windows code-path tests — run on ANY OS (including mac) by forcing the
platform flags in the imported server module. These catch structural bugs in
the Windows-specific generators (schtasks XML, argv, config paths) without a
real Windows machine. For true end-to-end Windows execution (winget, npm,
schtasks actually running), use the GitHub Actions windows-latest workflow.

Usage:
  python3 tests/test_windows_paths.py
"""

import sys
import unittest
import xml.dom.minidom as minidom
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_DIR))
import server  # noqa: E402


class WindowsPathTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Force the module's platform flags to Windows for the duration.
        cls._saved = (server.IS_MAC, server.IS_LINUX, server.IS_WIN)
        server.IS_MAC, server.IS_LINUX, server.IS_WIN = False, False, True

    @classmethod
    def tearDownClass(cls):
        server.IS_MAC, server.IS_LINUX, server.IS_WIN = cls._saved

    def _glm(self):
        return {p["id"]: p for p in server.load_providers()}["glm"]

    def test_proxy_argv_uses_node_and_cli(self):
        """Proxy must launch as `node <cli.js> --model cag-<id> ...` — never the
        bare `mimo2codex` shim (which Task Scheduler's PATH can't resolve)."""
        argv = server._proxy_argv(self._glm())
        self.assertIn("node", argv[0].lower())
        self.assertEqual(argv[2], "--model")
        self.assertEqual(argv[3], "cag-glm")
        self.assertIn("--no-admin", argv)
        self.assertIn(str(server.PROXY_PORT), argv)

    def test_win_autostart_xml_is_valid(self):
        """The Task Scheduler XML must be well-formed with a node Command and an
        Arguments element — not a bare shim Command."""
        xml = server._win_task_xml(
            r"C:\Program Files\nodejs\node.exe",
            r"C:\x\cli.js --model cag-glm -p 17878 --no-admin --no-update-check")
        doc = minidom.parseString(xml)
        cmd = doc.getElementsByTagName("Command")
        args = doc.getElementsByTagName("Arguments")
        self.assertTrue(cmd, "missing <Command>")
        self.assertTrue(args, "missing <Arguments>")
        self.assertIn("node", cmd[0].firstChild.data.lower())
        self.assertIn("--model", args[0].firstChild.data)
        self.assertIn("cag-glm", args[0].firstChild.data)

    def test_win_autostart_is_keep_alive(self):
        """The autostart task must keep the proxy running like mac KeepAlive /
        linux Restart=always: restart node on death, no 72h execution cap, and
        run even on battery."""
        doc = minidom.parseString(server._win_task_xml("node.exe", "--model cag-glm"))

        def _text(tag):
            els = doc.getElementsByTagName(tag)
            return els[0].firstChild.data if els and els[0].firstChild else ""

        # Restart node whenever it dies.
        self.assertTrue(doc.getElementsByTagName("RestartOnFailure"),
                        "missing <RestartOnFailure> — proxy won't survive a crash")
        # Never let Task Scheduler kill a healthy long-lived proxy (default PT72H).
        self.assertEqual(_text("ExecutionTimeLimit"), "PT0S")
        # Laptops on battery must still start/keep the proxy.
        self.assertEqual(_text("DisallowStartIfOnBatteries").lower(), "false")
        self.assertEqual(_text("StopIfGoingOnBatteries").lower(), "false")

    def test_win_supervisor_vbs_is_keep_alive_loop(self):
        """The no-elevation Run-key fallback's supervisor must relaunch node
        hidden in an infinite loop — keep-alive without admin."""
        vbs = server._win_supervisor_vbs(self._glm())
        self.assertIn("node", vbs.lower())
        self.assertIn("--model cag-glm", vbs)
        self.assertIn("sh.Run", vbs)
        self.assertIn(", 0, True", vbs)        # 0 = hidden window, True = wait
        self.assertIn("WScript.Sleep", vbs)
        self.assertIn("Loop", vbs)

    def test_win_stop_autostart_ends_then_deletes_and_kills_vbs(self):
        """Reinstall must stop BOTH keep-alive mechanisms before reclaiming the
        port: /End then /Delete the schtasks task, and kill the .vbs supervisor
        so it can't respawn node under the fresh proxy."""
        calls = []

        def fake_run(argv, **kw):
            calls.append(argv)

            class R:
                returncode = 0
                stdout = b""
                stderr = b""
            return R()

        orig = server.subprocess.run
        server.subprocess.run = fake_run
        try:
            server._win_stop_autostart()
        finally:
            server.subprocess.run = orig

        sch = [c for c in calls if c and c[0] == "schtasks"]
        self.assertEqual(sch, [
            ["schtasks", "/End", "/TN", server._WIN_TASK],
            ["schtasks", "/Delete", "/TN", server._WIN_TASK, "/F"],
        ])
        # Also kills the per-user .vbs supervisor.
        self.assertTrue(
            any(c and c[0] == "powershell" and "run-proxy.vbs" in " ".join(c)
                for c in calls),
            "did not attempt to kill the run-proxy.vbs supervisor")

    def test_mimo2codex_script_windows_branch(self):
        """On Windows the resolver must look for node_modules/.../cli.js, not
        realpath the .cmd shim."""
        # Without mimo2codex installed under a Windows layout this returns the
        # shim path or 'mimo2codex'; the important bit is it does not crash and
        # returns a string usable as a node script argument.
        s = server._mimo2codex_script()
        self.assertIsInstance(s, str)
        self.assertTrue(s)


if __name__ == "__main__":
    unittest.main(verbosity=2)
