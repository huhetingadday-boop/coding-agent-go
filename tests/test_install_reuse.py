#!/usr/bin/env python3
"""
Install-reuse tests: the installer must detect agents the user already has and
not install a second copy, while still ignoring a stale shim on PATH that
forwards to the wrong npm package.

All tests run in-process and offline. They mock npm/PATH lookups and never
touch the real home directory: the only test that writes a file (the gemini
shim) redirects HOME to a throwaway temp dir first.

Covers:
  - _target_is_npm_pkg: does a PATH-resolved binary really belong to a package?
  - _has_our: npm has the package AND the PATH binary belongs to it.
  - _plan (gemini): the "装 llxprt-code" step fires only when llxprt is missing.
  - _ensure_gemini_shim: writes an idempotent `gemini` -> `llxprt` forwarder.

Usage:
  python3 tests/test_install_reuse.py
"""

import os
import sys
import unittest
import unittest.mock as mock
from contextlib import contextmanager
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_DIR))
import server  # noqa: E402

CLAUDE = "@anthropic-ai/claude-code"
LLXPRT = "@vybestack/llxprt-code"
CODEX = "@openai/codex"


def _noop_sse(**kwargs):
    pass


def _logger():
    """Return (sse, logs) where logs collects every kwargs dict passed."""
    logs = []

    def sse(**kwargs):
        logs.append(kwargs)

    return sse, logs


@contextmanager
def temp_home():
    """Redirect Path.home() and HOME/USERPROFILE to a throwaway dir."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        with mock.patch.object(server.Path, "home", return_value=Path(d)), \
             mock.patch.dict(os.environ, {"HOME": d, "USERPROFILE": d}):
            yield Path(d)


def _which_factory(present):
    """which(cmd) -> a fake path when cmd is in `present`, else None."""
    return lambda cmd: (f"/usr/bin/{cmd}" if cmd in present else None)


class TargetIsNpmPkgTest(unittest.TestCase):
    """_target_is_npm_pkg matches a binary to its owning npm package using the
    node_modules layout, so a wrong-package shim never counts as a match.
    Paths are fake and non-existent, so resolution falls back to plain string
    matching — no filesystem is touched."""

    def t(self, path, pkg):
        return server._target_is_npm_pkg(path, pkg)

    def test_scoped_pkg_inside_node_modules_true(self):
        self.assertTrue(
            self.t("/fake/lib/node_modules/@anthropic-ai/claude-code/cli.js",
                   CLAUDE))

    def test_scoped_pkg_path_is_pkg_dir_true(self):
        self.assertTrue(
            self.t("/fake/lib/node_modules/@anthropic-ai/claude-code", CLAUDE))

    def test_wrong_scoped_pkg_false(self):
        # A @google/gemini-cli binary must NOT count as @vybestack/llxprt-code.
        self.assertFalse(
            self.t("/fake/lib/node_modules/@google/gemini-cli/dist/index.js",
                   LLXPRT))

    def test_unscoped_pkg_inside_node_modules_true(self):
        self.assertTrue(
            self.t("/fake/lib/node_modules/mimo2codex/bin/cli.js", "mimo2codex"))

    def test_bin_launcher_alias_true(self):
        self.assertTrue(self.t("/fake/lib/node_modules/.bin/llxprt", LLXPRT))

    def test_bin_pkg_last_segment_true(self):
        self.assertTrue(
            self.t("/fake/lib/node_modules/.bin/llxprt-code", LLXPRT))

    def test_stale_bin_shim_wrong_name_false(self):
        # `.bin/gemini` does not belong to llxprt-code (alias is `llxprt`).
        self.assertFalse(self.t("/fake/lib/node_modules/.bin/gemini", LLXPRT))

    def test_claude_alias_bin_true(self):
        self.assertTrue(self.t("/fake/lib/node_modules/.bin/claude", CLAUDE))

    def test_empty_or_none_path_false(self):
        self.assertFalse(self.t("", CLAUDE))
        self.assertFalse(self.t(None, CLAUDE))


class HasOurTest(unittest.TestCase):
    """_has_our combines `npm ls -g` with a PATH-ownership check."""

    def test_false_when_npm_missing(self):
        with mock.patch.object(server, "_npm_has", lambda pkg: False):
            self.assertFalse(server._has_our("claude", CLAUDE))

    def test_true_when_npm_has_but_not_on_path(self):
        with mock.patch.object(server, "_npm_has", lambda pkg: True), \
             mock.patch.object(server.shutil, "which", lambda cmd: None):
            self.assertTrue(server._has_our("claude", CLAUDE))

    def test_true_when_path_binary_belongs_to_pkg(self):
        on_path = "/fake/lib/node_modules/@anthropic-ai/claude-code/cli.js"
        with mock.patch.object(server, "_npm_has", lambda pkg: True), \
             mock.patch.object(server.shutil, "which", lambda cmd: on_path):
            self.assertTrue(server._has_our("claude", CLAUDE))

    def test_false_when_path_binary_is_wrong_pkg_shim(self):
        # npm reports llxprt installed, but `gemini` on PATH forwards to the
        # Google CLI — that stale shim must NOT satisfy _has_our.
        stale = "/fake/lib/node_modules/@google/gemini-cli/dist/index.js"
        with mock.patch.object(server, "_npm_has", lambda pkg: True), \
             mock.patch.object(server.shutil, "which", lambda cmd: stale):
            self.assertFalse(server._has_our("gemini", LLXPRT))


class PlanGeminiTest(unittest.TestCase):
    """_plan('gemini', ...) only adds the install step when llxprt is missing,
    and always keeps the config + connectivity steps."""

    @classmethod
    def setUpClass(cls):
        cls._saved = (server.IS_MAC, server.IS_LINUX, server.IS_WIN)
        server.IS_MAC, server.IS_LINUX, server.IS_WIN = False, True, False

    @classmethod
    def tearDownClass(cls):
        server.IS_MAC, server.IS_LINUX, server.IS_WIN = cls._saved

    def _labels(self, *, has_llxprt, present):
        pv = {"base_url": "u", "model": "m", "fast_model": "f"}
        with mock.patch.object(server, "_has_our",
                               lambda cmd, pkg: has_llxprt), \
             mock.patch.object(server, "_which", _which_factory(present)), \
             mock.patch.object(server, "_gh_authed", lambda: False):
            steps = server._plan("gemini", pv, "key", _noop_sse)
        return [s[0] for s in steps]

    def test_reuses_existing_llxprt(self):
        labels = self._labels(has_llxprt=True, present={"node", "gh"})
        self.assertNotIn("装 llxprt-code", labels)
        self.assertIn("写 llxprt 配置", labels)
        self.assertIn("试试能不能通", labels)

    def test_installs_llxprt_when_missing(self):
        labels = self._labels(has_llxprt=False, present={"node", "gh"})
        self.assertIn("装 llxprt-code", labels)

    def test_installs_node_only_when_missing(self):
        with_node = self._labels(has_llxprt=True, present={"node", "gh"})
        self.assertNotIn("装 Node.js", with_node)
        without_node = self._labels(has_llxprt=True, present={"gh"})
        self.assertIn("装 Node.js", without_node)


class GeminiShimTest(unittest.TestCase):
    """_ensure_gemini_shim writes an idempotent `gemini` -> `llxprt` forwarder
    under ~/.local/bin, redirected here to a throwaway HOME."""

    def setUp(self):
        self._saved_test_mode = server.TEST_MODE
        server.TEST_MODE = False  # otherwise the shim write is skipped

    def tearDown(self):
        server.TEST_MODE = self._saved_test_mode

    def test_writes_executable_forwarder(self):
        with temp_home() as home:
            sse, logs = _logger()
            server._ensure_gemini_shim(sse)
            shim = home / ".local" / "bin" / "gemini"
            self.assertTrue(shim.exists(), "shim not written")
            text = shim.read_text(encoding="utf-8")
            self.assertIn("llxprt", text)
            self.assertIn("Re-run the coding-agent-go installer", text)
            self.assertTrue(os.access(shim, os.X_OK), "shim not executable")

    def test_idempotent_second_call_skips(self):
        with temp_home():
            server._ensure_gemini_shim(_noop_sse)
            sse, logs = _logger()
            server._ensure_gemini_shim(sse)  # identical content already there
            joined = " ".join(l.get("log", "") for l in logs)
            self.assertIn("跳过", joined)


if __name__ == "__main__":
    unittest.main(verbosity=2)
