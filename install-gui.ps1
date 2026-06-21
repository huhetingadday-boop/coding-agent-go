<#
  coding-agent-go GUI launcher for Windows PowerShell.

  Run it the simple "curl | sh" way (downloads and runs in one shot):
    irm https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@main/install-gui.ps1 | iex

  It finds Python (installs it per-user if missing, no admin needed), fetches
  server.py + providers.json from the CDN, then starts the local install UI at
  http://localhost:17860 and opens your browser. No clone required.
#>
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Port = 17860
$Cdn  = 'https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@main'

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
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id Python.Python.3.12 --silent `
      --accept-package-agreements --accept-source-agreements
  } else {
    Write-Host 'No winget found; downloading the python.org installer...'
    $exe = Join-Path $env:TEMP 'py-installer.exe'
    Invoke-WebRequest 'https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe' `
      -OutFile $exe -UseBasicParsing
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
Invoke-WebRequest "$Cdn/server.py"      -OutFile (Join-Path $dir 'server.py')      -UseBasicParsing
Invoke-WebRequest "$Cdn/providers.json" -OutFile (Join-Path $dir 'providers.json') -UseBasicParsing

Write-Host "Starting coding-agent-go GUI on http://localhost:$Port ..."
Start-Process "http://localhost:$Port"
& $py (Join-Path $dir 'server.py') --port $Port
