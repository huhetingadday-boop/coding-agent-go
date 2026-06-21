#!/usr/bin/env python3
"""
Thinking-mode tests for the connectivity check and Claude config writer.

These run fully offline and in-process: the upstream call is mocked, so no
network is used, and every config write is redirected to a throwaway HOME so
the real ~/.claude/settings.json is never touched.

Covers:
  - Kimi-class models (thinking_required) send thinking on the FIRST ping.
  - A plain provider self-heals: if the upstream rejects a no-thinking request
    with a "thinking must be enabled" 400, we retry once WITH thinking.
  - A genuine 400 (not about thinking) still raises and does NOT retry.
  - _write_claude_cfg sets MAX_THINKING_TOKENS only for thinking_required
    providers, and drops it when switching back to a plain provider.

Usage:
  python3 tests/test_verify_thinking.py
"""

import io
import json
import os
import types
import unittest
import unittest.mock as mock
import urllib.error
from contextlib import contextmanager
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
import sys
sys.path.insert(0, str(PROJECT_DIR))
import server  # noqa: E402


def _noop_sse(**kwargs):
    pass


def _payload_of(req):
    return json.loads(req.data.decode("utf-8"))


def _http_error(code, body):
    return urllib.error.HTTPError(
        "https://example.test/v1/messages", code, "err", {}, io.BytesIO(body))


def _fake_urlopen(responses):
    """Return (fake_urlopen, captured_requests). `responses` is a list whose
    items are either an int status (200) or an Exception to raise."""
    seq = list(responses)
    calls = []

    def fake(req, timeout=None):
        calls.append(req)
        item = seq.pop(0)
        if isinstance(item, Exception):
            raise item
        return types.SimpleNamespace(status=item)

    return fake, calls


@contextmanager
def temp_home():
    """Redirect Path.home() (and HOME/USERPROFILE) to a throwaway dir so no
    config write reaches the real home directory."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        with mock.patch.object(server.Path, "home", return_value=Path(d)), \
             mock.patch.dict(os.environ, {"HOME": d, "USERPROFILE": d}):
            yield Path(d)


class VerifyThinkingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # _verify_claude short-circuits when TEST_MODE is on; force it off so
        # the (mocked) request path actually runs.
        cls._saved_test_mode = server.TEST_MODE
        server.TEST_MODE = False

    @classmethod
    def tearDownClass(cls):
        server.TEST_MODE = cls._saved_test_mode

    def _pv(self, **extra):
        pv = {"base_url": "https://example.test", "model": "m",
              "fast_model": "f"}
        pv.update(extra)
        return pv

    def test_kimi_sends_thinking_on_first_ping(self):
        """thinking_required providers must enable thinking up front, with a
        valid budget (>=1024 and strictly below max_tokens)."""
        fake, calls = _fake_urlopen([200])
        with mock.patch.object(server.urllib.request, "urlopen", fake):
            server._verify_claude(_noop_sse, self._pv(thinking_required=True),
                                  "key")
        self.assertEqual(len(calls), 1, "must not retry on a clean 200")
        p = _payload_of(calls[0])
        self.assertEqual(p["thinking"]["type"], "enabled")
        self.assertGreaterEqual(p["thinking"]["budget_tokens"], 1024)
        self.assertGreater(p["max_tokens"], p["thinking"]["budget_tokens"])

    def test_plain_provider_self_heals_on_thinking_400(self):
        """A plain provider pings WITHOUT thinking first; if the upstream says
        thinking must be enabled, it retries once WITH thinking and succeeds."""
        err = _http_error(
            400, b'{"error":"invalid thinking: only type=enabled is allowed"}')
        fake, calls = _fake_urlopen([err, 200])
        with mock.patch.object(server.urllib.request, "urlopen", fake):
            server._verify_claude(_noop_sse, self._pv(), "key")
        self.assertEqual(len(calls), 2, "must retry exactly once")
        self.assertNotIn("thinking", _payload_of(calls[0]))
        self.assertEqual(_payload_of(calls[1])["thinking"]["type"], "enabled")

    def test_real_400_still_raises(self):
        """A 400 that is NOT about thinking must raise and must NOT retry."""
        err = _http_error(400, b'{"error":"model not found"}')
        fake, calls = _fake_urlopen([err])
        with mock.patch.object(server.urllib.request, "urlopen", fake):
            with self.assertRaises(Exception):
                server._verify_claude(_noop_sse, self._pv(), "key")
        self.assertEqual(len(calls), 1, "must not retry a non-thinking 400")


class WriteClaudeCfgThinkingTest(unittest.TestCase):
    def test_write_cfg_sets_max_thinking_only_when_required(self):
        """MAX_THINKING_TOKENS is written for thinking_required providers and
        removed when switching back to a plain provider (settings are merged)."""
        with temp_home() as home:
            cfg = home / ".claude" / "settings.json"

            server._write_claude_cfg(
                _noop_sse, {"base_url": "u", "model": "m", "fast_model": "f",
                            "thinking_required": True}, "k")
            data = json.loads(cfg.read_text(encoding="utf-8"))
            self.assertEqual(data["env"]["MAX_THINKING_TOKENS"], "1024")

            # Switch to a plain provider: the leftover must be dropped.
            server._write_claude_cfg(
                _noop_sse, {"base_url": "u", "model": "m", "fast_model": "f"},
                "k")
            data = json.loads(cfg.read_text(encoding="utf-8"))
            self.assertNotIn("MAX_THINKING_TOKENS", data["env"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
