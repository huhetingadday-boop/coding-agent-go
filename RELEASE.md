# Releasing

The public install commands point at jsdelivr `@latest`, which resolves to the
**newest git tag** — never an untagged `main` commit. So pushing to `main` never
changes what users install. Only tagging does. This keeps a viral post's command
stable (the text never changes) while still letting a tagged fix reach everyone
who runs it.

## Cut a new version
1. Land your changes on `main` and wait for the `tests` workflow to go green. Never tag a red build — `@latest` ships a new tag to every user instantly.
2. Tag and push (use the next semver):
```bash
git tag v1.1.0
git push origin v1.1.0
```
3. Pushing the tag triggers `build-release.yml`, which builds the double-click `.exe` (Windows) and `.dmg` (macOS, Apple Silicon `.app`), and attaches each with its `.sha256` to the GitHub Release. The download page's `releases/latest/download/...` links go live as soon as this finishes.
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
- Download page: enable it once at repo Settings → Pages → Source → "GitHub Actions" (the `pages.yml` workflow deploys `docs/`). It lives at <https://huhetingadday-boop.github.io/coding-agent-go/> and is also reachable via jsDelivr without setup. The page's download buttons point at `releases/latest/download/...`, so they always track the newest release once one exists.
- The `.dmg` is built on the Apple-Silicon runner, so it targets M-series Macs. Intel Mac users should use the one-liner (or add a `macos-13` matrix entry to ship an x86_64 `.dmg`).
