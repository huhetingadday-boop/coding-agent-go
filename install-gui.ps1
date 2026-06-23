<#
  coding-agent-go GUI launcher for Windows PowerShell.

  Run it the simple "curl | sh" way (downloads and runs in one shot):
    irm https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest/install-gui.ps1 | iex

  It finds Python (installs it per-user if missing, no admin needed), fetches
  server.py + providers.json from the CDN, then starts the local install UI at
  http://localhost:17860 and opens your browser. No clone required.
#>
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Port = 17860
# Try a few jsDelivr endpoints — cdn. is occasionally throttled in China, but
# fastly./gcore. usually still resolve. All serve the same @latest tag.
$Cdns = @(
  'https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest',
  'https://fastly.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest',
  'https://gcore.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest'
)

function Find-Py {
  foreach ($c in @('py', 'python3', 'python')) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if (-not $cmd) { continue }
    # Skip the Windows Store alias stub (it lives under WindowsApps, opens the
    # Store, and is not a real interpreter).
    if ($cmd.Source -and $cmd.Source -match 'WindowsApps') { continue }
    return $c
  }
  return $null
}

$py = Find-Py
if (-not $py) {
  Write-Host 'Python 3 is required. Installing per-user (no admin needed)...'
  # Prefer winget, but it often fails in China (source-update errors). Fall back
  # to the python.org installer whenever winget is missing OR errors out, so a
  # broken winget source never aborts the whole install.
  $wingetOk = $false
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
      # --source winget skips the msstore source, which is the one that most
      # often fails to update behind China networks.
      winget install --id Python.Python.3.12 --silent --source winget `
        --accept-package-agreements --accept-source-agreements
      if ($LASTEXITCODE -eq 0) { $wingetOk = $true }
      else { Write-Host "winget failed (exit $LASTEXITCODE); falling back to python.org..." }
    } catch {
      Write-Host "winget failed ($($_.Exception.Message)); falling back to python.org..."
    }
  }
  if (-not $wingetOk) {
    Write-Host 'Downloading the Python installer (China mirror first, no VPN needed)...'
    $exe = Join-Path $env:TEMP 'py-installer.exe'
    # python.org is slow/blocked in mainland China, so try China mirrors first
    # and only fall back to the official site as a last resort.
    $pyUrls = @(
      'https://cdn.npmmirror.com/binaries/python/3.12.7/python-3.12.7-amd64.exe',
      'https://mirrors.huaweicloud.com/python/3.12.7/python-3.12.7-amd64.exe',
      'https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe'
    )
    $got = $false
    foreach ($u in $pyUrls) {
      try {
        Write-Host ("  downloading from " + ([Uri]$u).Host + " ...")
        Invoke-WebRequest $u -OutFile $exe -UseBasicParsing -TimeoutSec 180
        $got = $true; break
      } catch {
        Write-Host ("  " + ([Uri]$u).Host + " failed, trying the next mirror...")
      }
    }
    if (-not $got) { throw 'Python download failed from all mirrors. Check your network and retry.' }
    # InstallAllUsers=0 keeps it per-user so no admin/UAC prompt is needed.
    Start-Process $exe -ArgumentList '/quiet', 'InstallAllUsers=0', 'PrependPath=1', `
      'Include_pip=1', 'Include_launcher=1' -Wait
  }
  # Refresh PATH in this session so the freshly installed python is visible
  # without opening a new window.
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path', 'User')
  $py = Find-Py
  if (-not $py) {
    Write-Host 'Python installed. Please open a NEW PowerShell window and run the command again.'
    return
  }
}

# This script is piped from the web, so server.py is not on disk. Fetch the app
# into a temp dir from the China-friendly CDN.
$dir = Join-Path $env:TEMP 'coding-agent-go'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Write-Host 'Downloading server.py / providers.json ...'
function Fetch-File($name) {
  foreach ($base in $Cdns) {
    try {
      Invoke-WebRequest "$base/$name" -OutFile (Join-Path $dir $name) -UseBasicParsing -TimeoutSec 60
      return
    } catch {
      Write-Host ("  " + ([Uri]$base).Host + " failed for $name, trying the next mirror...")
    }
  }
  throw "Failed to download $name from all CDNs. Check your network, or use the .dmg/.exe installer."
}
Fetch-File 'server.py'
Fetch-File 'providers.json'

Write-Host "Starting coding-agent-go GUI on http://localhost:$Port (browser opens automatically) ..."
# Don't open the browser here: the server is not listening yet, so the tab would
# hit "can't connect" and need a manual refresh. server.py opens the browser
# itself right after it binds the socket, so the page is ready the moment the
# tab appears — one clean tab, no refresh.
& $py (Join-Path $dir 'server.py') --port $Port
