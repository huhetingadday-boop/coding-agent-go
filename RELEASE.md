# Releasing

The public install commands point at jsdelivr `@latest`, which resolves to the
**newest git tag** — never an untagged `main` commit. So pushing to `main` never
changes what users install. Only tagging does. This keeps a viral post's command
stable (the text never changes) while still letting a tagged fix reach everyone
who runs it.

## Cut a new version
1. Land your changes on `main` and wait for the `tests` workflow to go green. Never tag a red build — `@latest` ships a new tag to every user instantly.
2. Tag and push. Versions are CalVer `vYY.M.N` — `YY` = year, `M` = month, `N` = the Nth release that month (reset to 1 each month). So the first June-2026 release is `v26.6.1`, the next is `v26.6.2`, July's first is `v26.7.1`. Keep the leading `v`: `build-release.yml` triggers on `tags: ['v*']`, and jsDelivr `@latest` still orders these by semver (`26.6.1` > `1.1.1`), so it resolves to the newest.
```bash
git tag v26.6.1
git push origin v26.6.1
```
3. Pushing the tag triggers `build-release.yml`, which builds the double-click installers — `coding-agent-go-windows.exe` and `coding-agent-go-macos.dmg` (one universal2 build for both Intel and Apple Silicon) — each with its `.sha256`, and attaches them to the GitHub Release. The apps embed a native webview (pywebview), so the UI opens in its own window, not a browser. The download page's `releases/latest/download/...` links go live as soon as this finishes.
4. Refresh the jsdelivr cache so `@latest` resolves to the new tag right away (it caches floating refs for ~12h):
```bash
for f in install-gui.ps1 install-gui.sh install-gui.bat server.py providers.json docs/index.html; do
  curl -s "https://purge.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/$f" >/dev/null
done
```
5. Verify the served files match the tag:
```bash
curl -s "https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/server.py" | head -1
```

## Notes
- `@latest` needs at least one tag to exist. The first tag (`v1.0.0`) is what turns the public commands on.
- Fixed versions (`@v1.0.0`) are immutable and cached for a year — do not use them in the public command, or old posts can never receive a fix.
- The piped one-liner stays the primary install path; the packaged binaries are the zero-terminal option for non-technical users.
- Download page: enable it once at repo Settings → Pages → Source → "GitHub Actions" (the `pages.yml` workflow deploys `docs/`). It lives at <https://huhetingadday-boop.github.io/coding-agent-go/>. Pages is required to *render* it — jsDelivr serves `.html` as `text/plain` (shows source), so until Pages is on, the README download section is the no-setup path. The page's download buttons point at `releases/latest/download/...`, so they always track the newest release once one exists.
- macOS ships ONE `coding-agent-go-macos.dmg` — a universal2 binary built on the `macos-latest` (Apple-Silicon) runner with `--target-arch universal2`, so it runs on both Intel and Apple Silicon. This avoids the scarce/slow `macos-13` Intel runner entirely and means users never pick a chip. (pyobjc ships universal2 wheels and setup-python's macOS CPython is universal2, so the build resolves cleanly.) The `release` job uses `if: always()`, so a hiccup on one OS still publishes the other.
- The packaged app is a run-once installer (the `.dmg` holds just the app to double-click — no drag-to-Applications). Unsigned, so first open needs the one-time Gatekeeper/SmartScreen allow (documented in both READMEs).
