# coding-agent-go — one-shot environment diagnostic (Windows).
# Customers run it once and screenshot the output; the maintainer reads the
# report to pinpoint proxy / config / autostart / network / upstream problems
# WITHOUT asking the customer to run anything else.
#
# API keys are never printed — every dumped file, log line and command line is
# scrubbed, and the upstream key is reported as present/absent only.
#
#   Remote (recommended):
#     powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://gitee.com/huhetingadday-boop/coding-agent-go/raw/main/debug.ps1 | iex"
#   Local:
#     powershell -NoProfile -ExecutionPolicy Bypass -File debug.ps1 [-NoUpstream]

param([switch]$NoUpstream)

$ErrorActionPreference = 'SilentlyContinue'
try { chcp 65001 > $null; [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$PROXY_PORT = 17878
$TASK = 'coding-agent-go-mimo2codex'

# ---- secret scrubber: applied to EVERY externally-sourced string we print ----
function Redact($s) {
    if (-not $s) { return $s }
    $s = [string]$s
    # provider key shapes (sk-..., glm-..., xai-..., ds-..., gsk-...)
    $s = $s -replace '(?i)\b(sk|xai|glm|ds|gsk|key)[-_][A-Za-z0-9_\-]{6,}', '$1-***REDACTED***'
    # "api key: xxx", "X_API_KEY=xxx", "secret=xxx", "token: xxx"
    $s = $s -replace '(?i)((?:api[_\- ]?key|api[_\- ]?token|_API_KEY|secret|token)\s*[:=]\s*)("?)[^"\s,}]+', '${1}${2}***REDACTED***'
    # "authorization: Bearer <token>"
    $s = $s -replace '(?i)(bearer\s+)\S+', '${1}***REDACTED***'
    # JSON "api_key":"...", "token":"...", "authorization":"..."
    $s = $s -replace '(?i)("(?:api[_\-]?key|token|secret|authorization)"\s*:\s*")[^"]+', '${1}***REDACTED***'
    return $s
}

function Head($t) {
    Write-Host ""
    Write-Host (("  " + $t + " ").PadRight(70, '-')) -ForegroundColor Cyan
}
function Row($k, $v, $color = 'Gray') {
    Write-Host ("  {0,-16}" -f $k) -NoNewline -ForegroundColor DarkGray
    Write-Host (Redact $v) -ForegroundColor $color
}
function Stat($k, $ok, $okText, $badText) {
    Write-Host ("  {0,-16}" -f $k) -NoNewline -ForegroundColor DarkGray
    if ($ok) { Write-Host ("[ OK ] " + (Redact $okText)) -ForegroundColor Green }
    else { Write-Host ("[FAIL] " + (Redact $badText)) -ForegroundColor Red }
}
function Note($t, $c = 'Yellow') { Write-Host ("  " + $t) -ForegroundColor $c }
function Cmd($n) { (Get-Command $n -EA 0).Source }
function Ver($n, $a) { try { [string](& $n $a 2>$null | Select-Object -First 1).Trim() } catch { "" } }
function TcpTest($h, $pt) {
    try {
        $c = New-Object Net.Sockets.TcpClient
        $iar = $c.BeginConnect($h, $pt, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(3000, $false) -and $c.Connected
        $c.Close(); if ($ok) { "reachable" } else { "BLOCKED / timeout" }
    } catch { "error" }
}
function PortOwners($p) {
    $conns = Get-NetTCPConnection -LocalPort $p -State Listen -EA 0
    if (-not $conns) { return @("(nothing listening)") }
    $conns | ForEach-Object {
        $opid = $_.OwningProcess
        $pr = (Get-Process -Id $opid -EA 0).ProcessName
        $cl = (Get-CimInstance Win32_Process -Filter "ProcessId=$opid" -EA 0).CommandLine
        Redact (("PID {0}  {1}  ::  {2}" -f $opid, $pr, ($cl -replace '\s+', ' ')))
    } | Select-Object -Unique
}
function Dump($path, $n) {
    if (Test-Path $path) { Get-Content $path -TotalCount $n -EA 0 | ForEach-Object { Write-Host ("    " + (Redact $_)) -ForegroundColor DarkGray } }
    else { Write-Host "    (not found)" -ForegroundColor DarkGray }
}
function Tail($path, $n) {
    if (Test-Path $path) { Get-Content $path -Tail $n -EA 0 | ForEach-Object { Write-Host ("    " + (Redact $_)) -ForegroundColor DarkGray } }
    else { Write-Host "    (no file: $path)" -ForegroundColor DarkGray }
}
# Error-only extraction — skip the INFO/DEBUG firehose, keep just the failures.
$ERRPAT = '(?i)(error|fail|失败|denied|拒绝|refus|timed? ?out|超时|unreach|不通|exception|traceback|ENOENT|ECONNREFUSED|EADDRINUSE|Bad Gateway|Unauthorized|Forbidden|Insufficient|balance|rc=[1-9]|status [45]\d\d)'
function ErrLines($path, $max) {
    if (-not (Test-Path $path)) { Write-Host "    (no file)" -ForegroundColor DarkGray; return }
    $m = Select-String -Path $path -Pattern $ERRPAT -EA 0 | Select-Object -Last $max
    if (-not $m) { Write-Host "    (no error lines — clean)" -ForegroundColor Green; return }
    $m | ForEach-Object { Write-Host ("    " + (Redact $_.Line)) -ForegroundColor Yellow }
}

# =====================================================================
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "   coding-agent-go   ·   environment diagnostic" -ForegroundColor White
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ("   " + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + "   host: " + $env:COMPUTERNAME) -ForegroundColor DarkGray

# ---------- system ----------
Head "system"
$osi = Get-CimInstance Win32_OperatingSystem
$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
Row "os"        ($osi.Caption + "  (build " + $osi.BuildNumber + ")")
Row "arch"      $env:PROCESSOR_ARCHITECTURE
Row "powershell" $PSVersionTable.PSVersion.ToString()
Row "codepage"  ("out=" + [Console]::OutputEncoding.WebName + "  locale=" + (Get-Culture).Name)
Row "user"      ($env:USERNAME + "   (admin/elevated: " + $elevated + ")") $(if ($elevated) { 'Gray' } else { 'Yellow' })
Row "home"      $env:USERPROFILE
Row "cwd"       (Get-Location).Path
Row "free disk" ([string][math]::Round((Get-PSDrive C).Free / 1GB, 1) + " GB on C:")

# ---------- network (China no-VPN path matters) ----------
Head "network"
Row "HTTP_PROXY"  $(if ($env:HTTP_PROXY) { $env:HTTP_PROXY } else { "(unset)" }) $(if ($env:HTTP_PROXY) { 'Yellow' } else { 'Gray' })
Row "HTTPS_PROXY" $(if ($env:HTTPS_PROXY) { $env:HTTPS_PROXY } else { "(unset)" }) $(if ($env:HTTPS_PROXY) { 'Yellow' } else { 'Gray' })
Row "NO_PROXY"    $(if ($env:NO_PROXY) { $env:NO_PROXY } else { "(unset)" })
foreach ($t in @(@('api.deepseek.com', 443), @('gitee.com', 443), @('registry.npmmirror.com', 443))) {
    $r = TcpTest $t[0] $t[1]
    Stat ($t[0]) ($r -eq 'reachable') $r $r
}

# ---------- toolchain ----------
Head "toolchain"
Stat "node"   ([bool](Cmd node))   ((Ver node --version) + "   " + (Cmd node)) "not found"
if (Cmd npm) { Stat "npm" $true ((Ver npm --version) + "   prefix=" + (& cmd /c "npm prefix -g" 2>$null) + "   registry=" + (& cmd /c "npm config get registry" 2>$null)) "" }
else { Stat "npm" $false "" "not found" }
Stat "codex"  ([bool](Cmd codex))  ((Ver codex --version) + "   " + (Cmd codex)) "not found"
Stat "claude" ([bool](Cmd claude)) (Cmd claude) "not found"
Stat "gh"     ([bool](Cmd gh))     (Cmd gh) "not found"
Stat "mimo2codex" ([bool](Cmd mimo2codex)) (Cmd mimo2codex) "not on PATH (may still be under node prefix)"

# ---------- codex config ----------
Head "codex config"
$cfgPath = if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'config.toml' } else { Join-Path $env:USERPROFILE '.codex\config.toml' }
Row "CODEX_HOME" $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "(unset -> default ~/.codex)" }) $(if ($env:CODEX_HOME) { 'Yellow' } else { 'Gray' })
$model = ""; $port = $PROXY_PORT; $baseUrl = ""; $wireApi = ""; $reqAuth = ""; $managed = $false
if (Test-Path $cfgPath) {
    $c = Get-Content $cfgPath -Raw
    if ($c) {
        $model   = [regex]::Match($c, '(?m)^\s*model\s*=\s*"([^"]+)"').Groups[1].Value
        $baseUrl = [regex]::Match($c, 'base_url\s*=\s*"([^"]+)"').Groups[1].Value
        $wireApi = [regex]::Match($c, 'wire_api\s*=\s*"([^"]+)"').Groups[1].Value
        $reqAuth = [regex]::Match($c, 'requires_openai_auth\s*=\s*(\w+)').Groups[1].Value
        $mp = [regex]::Match($baseUrl, ':(\d+)').Groups[1].Value; if ($mp) { $port = [int]$mp }
        $managed = $c -match 'coding-agent-go managed'
    }
    Row  "file"     $cfgPath Green
    Row  "managed"  $(if ($managed) { "coding-agent-go" } else { "NOT coding-agent-go (other/old/manual)" }) $(if ($managed) { 'Green' } else { 'Yellow' })
    Row  "model"    $model
    Row  "base_url" $baseUrl $(if ($baseUrl -match '127\.0\.0\.1|localhost') { 'Gray' } else { 'Red' })
    Stat "wire_api" ($wireApi -eq 'responses') "responses (ok for Codex 0.84+)" "$wireApi  (should be 'responses' for Codex 0.84+)"
    Stat "req_openai_auth" ($reqAuth -eq 'false') "false (proxy is zero-auth)" "$reqAuth  (expected false)"
    Write-Host "  --- config.toml (secrets scrubbed) ---" -ForegroundColor DarkGray
    Dump $cfgPath 40
}
else { Stat "file" $false "" "$cfgPath  (no codex config — installer not run?)" }
Row "auth.json"   $(if (Test-Path (Join-Path (Split-Path $cfgPath) 'auth.json')) { "present" } else { "absent" })
Row "claude code" $(if (Test-Path (Join-Path $env:USERPROFILE '.claude\settings.json')) { "installed (~/.claude present — Claude Code user)" } else { "not configured" })
# project-local .codex\config.toml on the path Codex walks (the home-dir trap)
$d = (Get-Location).Path; $proj = @()
while ($d) { $f = Join-Path $d '.codex\config.toml'; if (Test-Path $f) { $proj += $f }; $pp = Split-Path $d -Parent; if ($pp -eq $d) { break }; $d = $pp }
Row "project cfgs" $(if ($proj) { ($proj -join ' ; ') } else { "(none on cwd path)" }) $(if ($proj) { 'Yellow' } else { 'Gray' })

# ---------- mimo2codex config ----------
Head "mimo2codex config"
$m2c = Join-Path $env:USERPROFILE '.mimo2codex'
$envFile = Join-Path $m2c '.env'
$provJson = Join-Path $m2c 'providers.json'
# NB: guard the .NET regex against $null — Get-Content on a missing/empty file
# returns $null, and [regex]::Match($null,...) throws a TERMINATING error that
# $ErrorActionPreference='SilentlyContinue' does NOT catch (would kill the run).
$envRaw = if (Test-Path $envFile) { Get-Content $envFile -Raw } else { "" }
$keyName = if ($envRaw) { [regex]::Match($envRaw, '(?m)^\s*([A-Z0-9_]*API_KEY)\s*=').Groups[1].Value } else { "" }
Row "upstream key" $(if ($keyName) { "$keyName present (value hidden)" } else { "absent" }) $(if ($keyName) { 'Green' } else { 'Red' })
Write-Host "  --- providers.json (secrets scrubbed) ---" -ForegroundColor DarkGray
Dump $provJson 40

# ---------- proxy ----------
Head "proxy (config port $port)"
# Check the configured port, our default 17878, AND 15721 (a non-coding-agent-go
# port seen in the field — surfaces a stray/other proxy the maintainer should know about).
foreach ($pp in @($port, 17878, 15721) | Select-Object -Unique) {
    $owners = @(PortOwners $pp)
    Write-Host ("  port {0}" -f $pp) -NoNewline -ForegroundColor DarkGray
    if ($owners[0] -eq '(nothing listening)') { Write-Host "   (nothing listening)" -ForegroundColor Red }
    else { Write-Host ""; $owners | ForEach-Object { Write-Host ("      " + $_) -ForegroundColor Green } }
}
$modelsOk = $false
try { $modelsOk = ((Invoke-WebRequest -UseBasicParsing -TimeoutSec 4 "http://127.0.0.1:$port/v1/models").StatusCode -eq 200) } catch {}
Stat "GET /v1/models" $modelsOk "HTTP 200 (proxy alive)" "no response (proxy down)"

# ---------- upstream probe (1 tiny real request -> reveals 502 cause) ----------
Head "upstream probe"
if ($NoUpstream) { Note "skipped (-NoUpstream)" 'DarkGray' }
elseif ($modelsOk -and $model) {
    Write-Host "  sending 2 tiny requests through the proxy to the model upstream..." -ForegroundColor DarkGray
    function Probe($label, $path, $body) {
        try {
            $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 -Method POST -ContentType 'application/json' -Body $body "http://127.0.0.1:$port$path"
            Stat $label $true "HTTP $($r.StatusCode) — OK" ""
        } catch {
            $ub = ""; try { $ub = (New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch {}
            Stat $label $false "" $_.Exception.Message
            if ($ub) { $t = Redact (($ub -replace '\s+', ' ').Trim()); Write-Host ("     body: " + $t.Substring(0, [Math]::Min(300, $t.Length))) -ForegroundColor Yellow }
        }
    }
    # /v1/responses is the path Codex actually uses (wire_api="responses"); chat is
    # a cross-check. If chat passes but responses fails -> the proxy's Responses->Chat
    # translation is the fault, not the upstream.
    Probe "/v1/responses"        "/v1/responses"        ('{"model":"' + $model + '","input":"ping","max_output_tokens":16}')
    Probe "/v1/chat/completions" "/v1/chat/completions" ('{"model":"' + $model + '","messages":[{"role":"user","content":"ping"}],"max_tokens":4,"stream":false}')
}
else { Note "skipped (proxy down or model unknown)" 'DarkGray' }

# ---------- autostart ----------
Head "autostart"
$st = Get-ScheduledTask -TaskName $TASK -EA 0
$sti = if ($st) { Get-ScheduledTaskInfo -TaskName $TASK -EA 0 } else { $null }
Stat "task scheduler" ([bool]$st) ("state=" + $st.State + "  lastResult=" + $sti.LastTaskResult) "none (denied without admin on UAC admin accounts — expected)"
$rk = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $TASK -EA 0).$TASK
Stat "HKCU Run key"  ([bool]$rk) ("no-admin fallback -> " + (Redact $rk)) "none"
Stat "run-proxy.vbs" (Test-Path (Join-Path $m2c 'run-proxy.vbs')) "present" "missing"
$sup = Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -EA 0 | Where-Object { $_.CommandLine -like '*run-proxy.vbs*' }
Stat "vbs supervisor" ([bool]$sup) ("running (PID " + ($sup.ProcessId -join ',') + ")") "not running (starts at next logon)"

# ---------- coding-agent-go logs (dir = %TEMP%) ----------
Head "coding-agent-go logs  (dir: $env:TEMP)"
foreach ($lf in 'coding-agent-go-debug.log', 'coding-agent-go-proxy.log', 'coding-agent-go-proxy.err') {
    $p = Join-Path $env:TEMP $lf
    if (Test-Path $p) { $fi = Get-Item $p; Row $lf ("{0} KB   modified {1}" -f [math]::Round($fi.Length / 1KB, 1), $fi.LastWriteTime.ToString('MM-dd HH:mm')) }
    else { Row $lf "(absent)" 'DarkGray' }
}
Head "install errors  (debug.log — error lines only)"
ErrLines (Join-Path $env:TEMP 'coding-agent-go-debug.log') 20
Head "proxy errors  (proxy.log / proxy.err — error lines only)"
ErrLines (Join-Path $env:TEMP 'coding-agent-go-proxy.log') 15
ErrLines (Join-Path $env:TEMP 'coding-agent-go-proxy.err') 10

# ---------- verdict ----------
Head "verdict"
if (-not (Test-Path $cfgPath)) { Note "* No codex config — run the coding-agent-go installer first." }
elseif (-not $modelsOk) {
    Note "* Proxy is DOWN on port $port (local proxy not answering)." 'Red'
    if (-not $st -and -not $rk) { Note "  Autostart not set -> reinstall (needs the no-admin autostart fix)." }
    else { Note "  Autostart exists but proxy isn't up now -> log out/in, or start it manually." }
}
else {
    Note "* Proxy is UP. A 5xx on the probes above = UPSTREAM fault" 'Green'
    Note "  (DeepSeek key / balance / network) — read the 'body:' line." 'Yellow'
    Note "  If /v1/responses fails but /v1/chat/completions passes -> proxy translation bug." 'Yellow'
}
if ($port -ne $PROXY_PORT) { Note "* base_url port is $port, not $PROXY_PORT — this config was NOT written by current coding-agent-go." }
if ($env:CODEX_HOME) { Note "* CODEX_HOME is set — codex reads config from there, not ~/.codex." }
if ($proj) { Note "* project-local .codex\config.toml found — Codex drops model_provider from those; keep provider config user-level." }
Write-Host ""
Write-Host "  ---- end of report · screenshot everything above ----" -ForegroundColor Cyan
Write-Host ""
