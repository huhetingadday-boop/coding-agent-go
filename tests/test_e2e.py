#!/usr/bin/env python3
"""
coding-agent-go — End-to-end tests for the GUI server.

These tests are SAFE to run anywhere (including via Claude itself):
  - The server runs with CAG_SELFTEST=1, so it skips every real side effect
    (package installs, network calls, daemon launches, agent smoke tests).
  - HOME is redirected to a throwaway temp dir, so config writes land there
    and NEVER touch the user's real ~/.claude, ~/.codex, ~/.llxprt-code, etc.
  - No API key is required: connectivity checks are skipped in self-test mode.

What they still cover (real regression protection):
  - HTTP routing, HTML rendering, provider loading, theme support
  - SSE streaming shape (log events + a single terminal done/error)
  - The install PLAN for each product (claude / codex / gemini) runs to "done"
  - The CONFIG FILES each product writes, with the correct content
  - Input validation (bad product, empty key) and concurrency safety

Usage:
  python3 tests/test_e2e.py
"""

import http.client
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
SERVER_PORT = 17861  # different from production to avoid conflicts


class E2ETest(unittest.TestCase):
    """Tests against a running coding-agent-go server in self-test mode."""

    srv = None
    home = None

    @classmethod
    def setUpClass(cls):
        # Throwaway HOME so config writes never touch the real ~/.
        cls.home = Path(tempfile.mkdtemp(prefix="cag-e2e-home-"))
        env = dict(os.environ)
        env["HOME"] = str(cls.home)
        env["USERPROFILE"] = str(cls.home)  # Windows
        env["CAG_SELFTEST"] = "1"
        # Capture the server's output so a startup failure (e.g. a Windows-only
        # encoding bug) is self-diagnosing instead of a bare timeout.
        cls._srvlog = Path(tempfile.mkstemp(prefix="cag-e2e-srv-")[1])
        logf = open(cls._srvlog, "w")
        cls.srv = subprocess.Popen(
            [sys.executable, str(PROJECT_DIR / "server.py"),
             "--port", str(SERVER_PORT)],
            stdout=logf, stderr=subprocess.STDOUT, env=env,
        )
        # The subprocess keeps its own dup of the fd; close ours so Windows can
        # delete the file later (it can't unlink a file the parent holds open).
        logf.close()
        for _ in range(60):
            time.sleep(0.2)
            try:
                conn = http.client.HTTPConnection("127.0.0.1", SERVER_PORT, timeout=2)
                conn.request("GET", "/")
                resp = conn.getresponse()
                resp.read()
                conn.close()
                if resp.status == 200:
                    break
            except Exception:
                pass
        else:
            out = cls._srvlog.read_text(encoding="utf-8", errors="replace")[-1500:]
            cls.tearDownClass()
            raise RuntimeError(f"Server did not start.\n--- server output ---\n{out}")

    @classmethod
    def tearDownClass(cls):
        if cls.srv:
            cls.srv.terminate()
            try:
                cls.srv.wait(timeout=3)
            except subprocess.TimeoutExpired:
                cls.srv.kill()
        if cls.home and cls.home.exists():
            shutil.rmtree(cls.home, ignore_errors=True)
        log = getattr(cls, "_srvlog", None)
        if log and log.exists():
            try:
                log.unlink(missing_ok=True)
            except OSError:
                pass  # Windows may still hold a lock briefly; harmless to leak

    # ── helpers ─────────────────────────────────────────────────────────
    def _get(self, path):
        conn = http.client.HTTPConnection("127.0.0.1", SERVER_PORT, timeout=10)
        try:
            conn.request("GET", path)
            resp = conn.getresponse()
            return resp.status, dict(resp.getheaders()), resp.read()
        finally:
            conn.close()

    def _post_json(self, path, body):
        data = json.dumps(body).encode()
        conn = http.client.HTTPConnection("127.0.0.1", SERVER_PORT, timeout=10)
        try:
            conn.request("POST", path, body=data,
                         headers={"content-type": "application/json"})
            resp = conn.getresponse()
            return resp.status, dict(resp.getheaders()), resp.read()
        finally:
            conn.close()

    def _install(self, product, provider_id, api_key, confirm=True, lang=None):
        """POST /api/install and read the full SSE stream. Returns events."""
        payload = {"product": product, "provider_id": provider_id,
                   "api_key": api_key, "confirm_overwrite": confirm}
        if lang is not None:
            payload["lang"] = lang
        data = json.dumps(payload).encode()
        conn = http.client.HTTPConnection("127.0.0.1", SERVER_PORT, timeout=20)
        try:
            conn.request("POST", "/api/install", body=data,
                         headers={"content-type": "application/json"})
            resp = conn.getresponse()
            ctype = resp.getheader("content-type", "")
            events, buf = [], b""
            while True:
                chunk = resp.read(4096)
                if not chunk:
                    break
                buf += chunk
                while b"\n\n" in buf:
                    block, buf = buf.split(b"\n\n", 1)
                    for line in block.split(b"\n"):
                        if line.startswith(b"data: "):
                            events.append(json.loads(line[6:]))
            return resp.status, ctype, events
        finally:
            conn.close()

    def _assert_completes(self, events):
        self.assertGreater(len(events), 0, "No SSE events received")
        self.assertTrue(any("log" in e for e in events), "No log events")
        terminal = [e for e in events if "done" in e or "error" in e]
        self.assertEqual(len(terminal), 1, f"Expected exactly one terminal event, got {terminal}")
        return terminal[0]

    def _provider(self, pid):
        """Read a provider entry from providers.json (source of truth)."""
        data = json.loads((PROJECT_DIR / "providers.json").read_text(encoding="utf-8"))
        for p in data["providers"]:
            if p["id"] == pid:
                return p
        raise KeyError(pid)

    # ── basic HTTP ──────────────────────────────────────────────────────
    def test_01_index_returns_html(self):
        status, headers, body = self._get("/")
        self.assertEqual(status, 200)
        self.assertIn("text/html", headers.get("content-type", "").lower())
        text = body.decode()
        self.assertIn("coding-agent-go", text)
        self.assertIn("Claude Code", text)
        self.assertIn("OpenAI Codex", text)
        self.assertIn("Gemini CLI", text)

    def test_02_index_has_all_steps(self):
        _, _, body = self._get("/")
        text = body.decode()
        for sid in ["s0", "s1", "s2", "s3"]:
            self.assertIn(f'id="{sid}"', text, f"Missing section {sid}")

    def test_03_product_order_claude_codex_gemini(self):
        """Intro order must be Claude Code -> OpenAI Codex -> Gemini CLI."""
        _, _, body = self._get("/")
        text = body.decode()
        i_claude = text.index("Claude Code")
        i_codex = text.index("OpenAI Codex")
        i_gemini = text.index("Gemini CLI")
        self.assertLess(i_claude, i_codex, "Claude must come before Codex")
        self.assertLess(i_codex, i_gemini, "Codex must come before Gemini")

    def test_04_index_loads_providers(self):
        _, _, body = self._get("/")
        text = body.decode()
        self.assertIn("智谱 GLM", text)
        self.assertIn("DeepSeek", text)

    def test_05_index_has_theme_support(self):
        _, _, body = self._get("/")
        text = body.decode()
        self.assertIn("prefers-color-scheme", text)
        self.assertIn("color-scheme: light dark", text)

    def test_06_s4_removed_no_done_page(self):
        """The separate s4 done page must not exist — completion stays on s3."""
        _, _, body = self._get("/")
        text = body.decode()
        self.assertNotIn('id="s4"', text)
        self.assertNotIn("done-icon", text)

    def test_07_favicon_returns_204(self):
        status, _, _ = self._get("/favicon.ico")
        self.assertEqual(status, 204)

    def test_08_404_on_unknown_path(self):
        status, _, _ = self._get("/nonexistent")
        self.assertEqual(status, 404)

    def test_09_cancel_returns_ok(self):
        status, _, body = self._post_json("/api/cancel", {})
        self.assertEqual(status, 200)
        self.assertTrue(json.loads(body).get("ok"))

    # ── install: Claude Code ────────────────────────────────────────────
    def test_10_claude_install_completes(self):
        status, ctype, events = self._install("claude", "glm", "test-key-12345678")
        self.assertEqual(status, 200)
        self.assertIn("text/event-stream", ctype)
        term = self._assert_completes(events)
        self.assertTrue(term.get("done"), f"Claude install did not finish cleanly: {term}")
        self.assertTrue(any("[self-test]" in e.get("log", "") for e in events),
                        "Self-test guard did not fire — real side effects may have run")

    def test_11_claude_writes_settings(self):
        self._install("claude", "glm", "test-key-12345678")
        cfg = self.home / ".claude" / "settings.json"
        self.assertTrue(cfg.exists(), "~/.claude/settings.json not written")
        data = json.loads(cfg.read_text(encoding="utf-8"))
        env = data.get("env", {})
        glm = self._provider("glm")
        self.assertEqual(env.get("ANTHROPIC_BASE_URL"), glm["base_url"])
        self.assertEqual(env.get("ANTHROPIC_AUTH_TOKEN"), "test-key-12345678")
        self.assertEqual(env.get("ANTHROPIC_MODEL"), glm["model"])

    # ── install: OpenAI Codex (direct, no proxy) ────────────────────────
    def test_20_codex_install_completes(self):
        status, ctype, events = self._install("codex", "deepseek", "test-key-12345678")
        self.assertEqual(status, 200)
        self.assertIn("text/event-stream", ctype)
        term = self._assert_completes(events)
        self.assertTrue(term.get("done"), f"Codex install did not finish cleanly: {term}")

    def test_21_codex_writes_proxy_config(self):
        self._install("codex", "deepseek", "test-key-12345678")
        # config.toml → Codex talks to local proxy via wire_api=responses
        cfg = self.home / ".codex" / "config.toml"
        self.assertTrue(cfg.exists(), "~/.codex/config.toml not written")
        toml = cfg.read_text(encoding="utf-8")
        self.assertIn('wire_api = "responses"', toml, "Codex 0.84+ requires wire_api=responses")
        self.assertIn("127.0.0.1:17878/v1", toml, "Codex must point at local mimo2codex proxy")
        self.assertIn("requires_openai_auth = false", toml, "Codex must connect without a key")

    def test_22_codex_writes_proxy_env(self):
        self._install("codex", "deepseek", "test-key-12345678")
        # Proxy .env → real provider key for the proxy daemon
        env_file = self.home / ".mimo2codex" / ".env"
        self.assertTrue(env_file.exists(), "~/.mimo2codex/.env not written")
        text = env_file.read_text(encoding="utf-8")
        self.assertIn("DEEPSEEK_API_KEY=test-key-12345678", text, "Real key must be in proxy .env")

    def test_23_codex_writes_generic_provider(self):
        """Regression: every provider must get a generic providers.json entry
        (id cag-<id>, chat baseUrl). The old code wrongly used --model ds for
        all, so non-DeepSeek providers never started."""
        for pid in ("glm", "kimi", "minimax"):
            self._install("codex", pid, "test-key-12345678")
            pf = self.home / ".mimo2codex" / "providers.json"
            self.assertTrue(pf.exists(), f"providers.json not written for {pid}")
            spec = json.loads(pf.read_text(encoding="utf-8"))["providers"][0]
            pv = self._provider(pid)
            self.assertEqual(spec["id"], "cag-" + pid)
            self.assertEqual(spec["baseUrl"], pv["chat_url"])
            self.assertEqual(spec["wireApi"], "chat")
            self.assertEqual(spec["defaultModel"], pv["model"])
            self.assertIn({"id": pv["model"]}, spec["models"])
        # MiniMax needs the strict-compat preset or upstream rejects requests
        self._install("codex", "minimax", "test-key-12345678")
        spec = json.loads((self.home / ".mimo2codex" / "providers.json").read_text(encoding="utf-8"))["providers"][0]
        self.assertTrue(spec.get("features", {}).get("minimaxCompat"), "MiniMax needs minimaxCompat")

    def test_24_codex_needs_no_env_var(self):
        """Codex must connect to the zero-auth proxy without any API key, so
        `codex` works in any terminal/shell — no env var, no shell export."""
        self._install("codex", "glm", "test-key-12345678")
        toml = (self.home / ".codex" / "config.toml").read_text(encoding="utf-8")
        self.assertIn("requires_openai_auth = false", toml, "Codex must not require an inbound key")
        self.assertNotIn("env_key", toml, "Codex must not depend on a shell env var")
        # And nothing should be written to any shell profile.
        for p in (self.home / ".profile", self.home / ".zshrc", self.home / ".bashrc"):
            if p.exists():
                self.assertNotIn("MIMO2CODEX", p.read_text(encoding="utf-8"), "No shell export should be needed")

    # ── install-log i18n ────────────────────────────────────────────────
    def test_25_english_lang_translates_step_labels(self):
        """lang=en must translate the high-level step labels (the progress
        'spine'). Chinese is the default; English mode should not show the
        Chinese label for a core step like 'write config'."""
        _, _, ev_en = self._install("claude", "glm", "test-key-12345678", lang="en")
        labels_en = [e.get("label", "") for e in ev_en if "label" in e]
        self.assertIn("Write config", labels_en, f"en labels missing English: {labels_en}")
        self.assertNotIn("写配置", labels_en, "en mode must not show the Chinese label")
        # zh stays the default and untranslated.
        _, _, ev_zh = self._install("claude", "glm", "test-key-12345678", lang="zh")
        labels_zh = [e.get("label", "") for e in ev_zh if "label" in e]
        self.assertIn("写配置", labels_zh, f"zh labels should stay Chinese: {labels_zh}")

    # ── install: Gemini CLI (llxprt-code) ───────────────────────────────
    def test_30_gemini_install_completes(self):
        status, ctype, events = self._install("gemini", "glm", "test-key-12345678")
        self.assertEqual(status, 200)
        self.assertIn("text/event-stream", ctype)
        term = self._assert_completes(events)
        self.assertTrue(term.get("done"), f"Gemini install did not finish cleanly: {term}")

    def test_31_gemini_writes_llxprt_config(self):
        self._install("gemini", "kimi", "test-key-12345678")
        cfg = self.home / ".llxprt-code" / "config.json"
        self.assertTrue(cfg.exists(), "~/.llxprt-code/config.json not written")
        data = json.loads(cfg.read_text(encoding="utf-8"))
        # Compare against providers.json so model-ID updates never break this.
        kimi = self._provider("kimi")
        self.assertEqual(data.get("provider"), "anthropic")
        self.assertEqual(data.get("apiKey"), "test-key-12345678")
        self.assertEqual(data.get("model"), kimi["model"])
        self.assertEqual(data.get("baseUrl"), kimi["base_url"])

    # ── overwrite consent + backup ──────────────────────────────────────
    def test_35_check_reports_existing_config(self):
        self._install("claude", "glm", "test-key-12345678")  # ensure config exists
        status, _, body = self._post_json("/api/check", {"product": "claude"})
        self.assertEqual(status, 200)
        existing = json.loads(body)["existing"]
        self.assertTrue(any("settings.json" in x for x in existing),
                        "check must report the existing settings.json")

    def test_36_install_without_consent_is_blocked(self):
        self._install("claude", "glm", "test-key-12345678")  # config now exists
        _, _, events = self._install("claude", "glm", "test-key-12345678", confirm=False)
        term = self._assert_completes(events)
        self.assertIn("error", term)
        self.assertIn("need_confirm", term, "server must signal which files need confirmation")

    def test_37_overwrite_creates_backup(self):
        self._install("claude", "glm", "test-key-12345678")  # config exists
        self._install("claude", "glm", "test-key-12345678", confirm=True)  # overwrite
        baks = list((self.home / ".claude").glob("settings.json.bak-*"))
        self.assertTrue(baks, "overwriting an existing config must leave a timestamped backup")

    # ── input validation ────────────────────────────────────────────────
    def test_40_invalid_product_errors(self):
        _, _, events = self._install("notaproduct", "glm", "test-key-12345678")
        term = self._assert_completes(events)
        self.assertIn("error", term)

    def test_41_empty_key_errors(self):
        _, _, events = self._install("claude", "glm", "")
        term = self._assert_completes(events)
        self.assertIn("error", term)

    def test_44_non_ascii_key_errors(self):
        """A key with non-ASCII chars must fail fast with a clear message,
        not a cryptic latin-1 codec error, and before any config is written."""
        _, _, events = self._install("codex", "deepseek", "sk-中文密钥abcdef")
        term = self._assert_completes(events)
        self.assertIn("error", term)
        self.assertIn("混了中文", term["error"])
        self.assertFalse((self.home / ".codex" / "config.toml").exists()
                         and "中文" in (self.home / ".codex" / "config.toml").read_text(encoding="utf-8"),
                         "Bad key must not be written to config")

    def test_42_unknown_provider_falls_back(self):
        _, _, events = self._install("claude", "nonexistent", "test-key-12345678")
        term = self._assert_completes(events)
        self.assertTrue(term.get("done"), "Unknown provider should fall back to the first provider")

    def test_43_malformed_json_errors_gracefully(self):
        conn = http.client.HTTPConnection("127.0.0.1", SERVER_PORT, timeout=10)
        try:
            conn.request("POST", "/api/install", body=b"{not json",
                         headers={"content-type": "application/json"})
            resp = conn.getresponse()
            self.assertEqual(resp.status, 200)
            body = resp.read().decode()
            self.assertIn("error", body)
            self.assertNotIn("Traceback", body)
        finally:
            conn.close()

    # ── concurrency & security ──────────────────────────────────────────
    def test_50_concurrent_requests(self):
        import threading
        results, errs = [], []

        def do_get():
            try:
                status, _, _ = self._get("/")
                results.append(status)
            except Exception as e:
                errs.append(e)

        threads = [threading.Thread(target=do_get) for _ in range(5)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=10)
        self.assertEqual(len(results), 5, f"Expected 5 results ({len(errs)} errors)")
        self.assertTrue(all(s == 200 for s in results), f"Non-200: {results}")

    def test_60_no_key_leakage_in_html(self):
        _, _, body = self._get("/")
        text = body.decode()
        self.assertNotIn("ANTHROPIC_AUTH_TOKEN", text)

    def test_61_content_length_set(self):
        for path in ["/", "/favicon.ico", "/nonexistent"]:
            _, headers, _ = self._get(path)
            self.assertIsNotNone(headers.get("content-length"), f"No Content-Length for {path}")

    def test_62_no_traceback_in_error_response(self):
        _, _, events = self._install("claude", "glm", "")
        blob = json.dumps(events)
        self.assertNotIn("Traceback", blob)
        self.assertNotIn('File "', blob)


class UnitTest(unittest.TestCase):
    """Pure-function unit tests that don't need a running server."""

    def test_friendly_error_is_localized(self):
        import re as _re
        sys.path.insert(0, str(PROJECT_DIR))
        import server
        has_cjk = lambda s: bool(_re.search(r"[一-鿿]", s))
        # English install: the on-failure message must carry no Chinese.
        server._ACTIVE_LANG = "en"
        for code in (401, 429, 500):
            msg = server._friendly_upstream_error(code, "")
            self.assertFalse(has_cjk(msg), f"en message for {code} has Chinese: {msg}")
        self.assertIn("balance", server._friendly_upstream_error(200, "insufficient balance"))
        # Chinese is the default.
        server._ACTIVE_LANG = "zh"
        self.assertIn("余额", server._friendly_upstream_error(200, "insufficient balance"))
        self.assertIn("API Key", server._friendly_upstream_error(401, ""))

    def test_better_sqlite3_seed_all_platforms(self):
        """The better-sqlite3 prebuilt seed must work on darwin/linux/win and
        fetch via a CN GitHub proxy first (the user may have no GitHub access)."""
        sys.path.insert(0, str(PROJECT_DIR))
        import server
        captured = {}

        def fake_download(url, dest, timeout=60):
            captured["url"] = url
            Path(dest).parent.mkdir(parents=True, exist_ok=True)
            Path(dest).write_bytes(b"x" * 2000)  # > 1000 bytes => "placed"

        orig = server._download
        server._download = fake_download
        try:
            for asset in ("a1-better-sqlite3-v12.11.1-node-v137-darwin-arm64.tar.gz",
                          "b2-better-sqlite3-v12.11.1-node-v127-linux-x64.tar.gz",
                          "c3-better-sqlite3-v12.11.1-node-v137-win32-x64.tar.gz"):
                captured.clear()
                log = f"prebuild-install warn install looking for cached prebuild @ /tmp/c/_prebuilds/{asset}"
                ok = server._seed_better_sqlite3_prebuild(lambda **k: None, log)
                self.assertTrue(ok, f"seed should place a prebuilt for {asset}")
                self.assertTrue(captured["url"].startswith(server.GH_PROXIES[0]),
                                f"must try a CN proxy first, got {captured['url']}")
                self.assertIn("WiseLibs/better-sqlite3/releases/download/v12.11.1", captured["url"])
                self.assertTrue(captured["url"].endswith(asset.split("-", 1)[1]), captured["url"])
        finally:
            server._download = orig

    @unittest.skipIf(os.name == "nt",
                     "PATH persistence is a macOS/Linux feature (Windows uses the "
                     "registry); Path.home() ignores $HOME on Windows, so this test "
                     "can't redirect writes to a temp dir there.")
    def test_persist_unix_path_idempotent(self):
        """The rustup-style PATH persister must add the bin dir to the shell
        profile exactly once, even if called repeatedly."""
        sys.path.insert(0, str(PROJECT_DIR))
        import server
        old_home, old_path = os.environ.get("HOME"), os.environ.get("PATH")
        td = tempfile.mkdtemp()
        try:
            os.environ["HOME"] = td
            bindir = "/tmp/fake/coding-agent-go/node/bin"
            server._persist_unix_path(bindir)
            server._persist_unix_path(bindir)  # called twice -> still one entry
            zprofile = Path(td) / ".zprofile"
            self.assertTrue(zprofile.exists(), "should write ~/.zprofile")
            content = zprofile.read_text(encoding="utf-8")
            self.assertEqual(content.count("# coding-agent-go"), 1, "must be idempotent")
            self.assertIn(bindir, content)
            self.assertIn(bindir, os.environ["PATH"])  # this process sees it too
        finally:
            if old_home is not None:
                os.environ["HOME"] = old_home
            if old_path is not None:
                os.environ["PATH"] = old_path
            shutil.rmtree(td, ignore_errors=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
