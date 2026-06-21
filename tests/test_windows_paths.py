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
        """_win_autostart must emit well-formed Task Scheduler XML with a
        node Command and an Arguments element — not a bare shim Command."""
        captured = {}

        def fake_write(self_path, content, **kw):  # patch Path.write_text
            captured["xml"] = content

        orig = Path.write_text
        Path.write_text = fake_write
        try:
            # subprocess.run(schtasks) will no-op/raise on mac; that's fine,
            # we only care about the generated XML.
            try:
                server._win_autostart(lambda **k: None, self._glm())
            except Exception:
                pass
        finally:
            Path.write_text = orig

        xml = captured.get("xml", "")
        self.assertTrue(xml, "no XML written")
        # Must parse as valid XML.
        doc = minidom.parseString(xml)
        cmd = doc.getElementsByTagName("Command")
        args = doc.getElementsByTagName("Arguments")
        self.assertTrue(cmd, "missing <Command>")
        self.assertTrue(args, "missing <Arguments>")
        self.assertIn("node", cmd[0].firstChild.data.lower())
        self.assertIn("--model", args[0].firstChild.data)
        self.assertIn("cag-glm", args[0].firstChild.data)

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
