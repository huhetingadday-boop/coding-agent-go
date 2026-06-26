@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title coding-agent-go GUI Installer

set PORT=17860
:parse
if "%~1"=="" goto :run
if "%~1"=="--port" (set PORT=%~2 & shift & shift & goto :parse)
if "%~1"=="-h" (echo Usage: install-gui.bat [--port ^<port^>] & goto :end)
if "%~1"=="--help" (echo Usage: install-gui.bat [--port ^<port^>] & goto :end)
echo Unknown: %~1 & exit /b 2

:run
rem Find Python. Prefer py (the launcher that ships with the official MSI)
rem because `python3` is only on PATH when the user checked "Add to PATH".
set PY=
for %%c in (py python3 python) do (
    where %%c >nul 2>&1 && (
        set PY=%%c
        goto :found
    )
)

rem Python not found — try winget first (Win10 21H1+/Win11), then the
rem official MSI as fallback (works without winget or Microsoft Store).
echo Python 3 is required.
where winget >nul 2>&1 && (
    echo Installing via winget...
    winget install --id Python.Python.3 --silent --source winget --disable-interactivity --accept-package-agreements --accept-source-agreements
    echo Please restart this script after Python installation completes.
    pause
    exit /b 1
)
echo No winget found; downloading Python installer (China mirror first, no VPN needed)...
set "MSI=%TEMP%\py-installer.exe"
rem InstallAllUsers=0 keeps it per-user so no admin/UAC is needed. China mirrors
rem first (python.org is slow/blocked in CN), official site only as last resort.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $urls=@('https://cdn.npmmirror.com/binaries/python/3.12.7/python-3.12.7-amd64.exe','https://mirrors.huaweicloud.com/python/3.12.7/python-3.12.7-amd64.exe','https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe'); $got=$false; foreach($u in $urls){ try{ Write-Host ('  downloading from '+([Uri]$u).Host+' ...'); Invoke-WebRequest -Uri $u -OutFile '%MSI%' -UseBasicParsing -TimeoutSec 180; $got=$true; break }catch{ Write-Host ('  '+([Uri]$u).Host+' failed, next mirror...') } }; if(-not $got){ throw 'Python download failed from all mirrors.' }; $p = Start-Process -FilePath '%MSI%' -ArgumentList '/quiet','InstallAllUsers=0','PrependPath=1','Include_pip=1','Include_launcher=1' -Wait -PassThru; exit $p.ExitCode } catch { Write-Host $_; exit 1 }"
if errorlevel 1 (
    echo Failed to install Python automatically. Please install manually from https://www.python.org/downloads/ and re-run.
    pause
    exit /b 1
)
echo Python installed. Please restart this script.
pause
exit /b 1

:found
echo Starting coding-agent-go GUI on http://localhost:%PORT% ...
rem server.py lives next to this .bat in a clone. When only this .bat was
rem downloaded (the PowerShell one-liner), fetch the app into TEMP first.
set "APPDIR=%~dp0"
if not exist "%APPDIR%server.py" call :fetch_app
cd /d "%APPDIR%"
rem Don't pre-open the browser here (server isn't up yet). server.py opens it
rem itself right after binding the socket, so the page is ready when the tab appears.
"%PY%" "%APPDIR%server.py" --port %PORT%
goto :end

:fetch_app
set "APPDIR=%TEMP%\coding-agent-go\"
if not exist "%APPDIR%" mkdir "%APPDIR%"
echo Downloading server.py / providers.json ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $d=Join-Path $env:TEMP 'coding-agent-go'; $bases=@('https://cdn.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest','https://fastly.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest','https://gcore.jsdelivr.net/gh/huhetingadday-boop/coding-agent-go@latest'); function Fetch($n){ foreach($b in $bases){ try{ Invoke-WebRequest ($b+'/'+$n) -OutFile (Join-Path $d $n) -UseBasicParsing -TimeoutSec 60; return }catch{} } throw ('download failed: '+$n) }; Fetch 'server.py'; Fetch 'providers.json'"
exit /b

:end
endlocal
