# Builds and starts the server and the web console together on Windows.
# Open http://localhost:5173 when it says "Ready". Press Ctrl+C to stop both.
#
#   .\run.ps1                 (or double-click run.cmd)
#   $env:SERVER_PORT=9090; $env:CLIENT_PORT=3000; .\run.ps1    (other ports)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-Location $PSScriptRoot
. "$PSScriptRoot\scripts\tools-env.ps1"

$ServerPort = if ($env:SERVER_PORT) { [int]$env:SERVER_PORT } else { 8080 }
$ClientPort = if ($env:CLIENT_PORT) { [int]$env:CLIENT_PORT } else { 5173 }
$Logs = Join-Path $PSScriptRoot 'logs'

function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Fail($m) { Write-Host "`nStopped: $m" -ForegroundColor Red; exit 1 }
function PortBusy($p) {
  $c = New-Object System.Net.Sockets.TcpClient
  try { $c.Connect('127.0.0.1', $p); return $true } catch { return $false } finally { $c.Close() }
}
function ServerUp {
  try { return (Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "http://localhost:$ServerPort/actuator/health").StatusCode -eq 200 }
  catch { return $false }
}
function ShowTail($file) { if (Test-Path $file) { Get-Content $file -Tail 30 } }

if (-not (Test-Path 'client\node_modules') -or -not (Test-Path 'client\.env')) { Fail "Run setup first: powershell -ExecutionPolicy Bypass -File init.ps1" }
if (PortBusy $ServerPort) { Fail "Port $ServerPort is in use. Close the program using it (maybe an earlier run), then try again." }
if (PortBusy $ClientPort) { Fail "Port $ClientPort is in use. Close the program using it (maybe an earlier run), then try again." }
New-Item -ItemType Directory -Force $Logs | Out-Null

Say "Building the server"
cmd /c "cd server && mvnw.cmd -q -DskipTests package > `"$Logs\server-build.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { ShowTail "$Logs\server-build.log"; Fail "Server build failed. Full log: logs\server-build.log" }
$Jar = Get-ChildItem 'server\target\*.jar' | Where-Object { $_.Name -notlike '*-plain.jar' } | Select-Object -First 1
if (-not $Jar) { Fail "Server build made no jar file. Full log: logs\server-build.log" }

Say "Building the web console"
cmd /c "npm.cmd run build --prefix client > `"$Logs\client-build.log`" 2>&1"
if ($LASTEXITCODE -ne 0) { ShowTail "$Logs\client-build.log"; Fail "Web console build failed. Full log: logs\client-build.log" }

$server = $null; $client = $null
try {
  Say "Starting the server (log: logs\server.log)"
  # Run from server\ so registered providers stay in server\db.json.
  $server = Start-Process -FilePath 'java' -ArgumentList '-jar', "`"$($Jar.FullName)`"", "--server.port=$ServerPort" `
    -WorkingDirectory "$PSScriptRoot\server" -NoNewWindow -PassThru `
    -RedirectStandardOutput "$Logs\server.log" -RedirectStandardError "$Logs\server-error.log"

  $up = $false
  for ($i = 0; $i -lt 90; $i++) {
    if ($server.HasExited) { ShowTail "$Logs\server.log"; ShowTail "$Logs\server-error.log"; Fail "Server did not start. Full log: logs\server.log" }
    if (ServerUp) { $up = $true; break }
    Start-Sleep -Seconds 1
  }
  if (-not $up) { Fail "Server did not answer within 90 seconds. Full log: logs\server.log" }

  Say "Starting the web console (log: logs\client.log)"
  # The console forwards /api to the server started above, whatever client\.env says.
  $env:DEV_PROXY_TARGET = "http://localhost:$ServerPort"
  $client = Start-Process -FilePath 'node' -ArgumentList 'node_modules\vite\bin\vite.js', 'preview', '--port', "$ClientPort", '--strictPort' `
    -WorkingDirectory "$PSScriptRoot\client" -NoNewWindow -PassThru `
    -RedirectStandardOutput "$Logs\client.log" -RedirectStandardError "$Logs\client-error.log"

  for ($i = 0; $i -lt 30; $i++) {
    if ($client.HasExited) { ShowTail "$Logs\client.log"; ShowTail "$Logs\client-error.log"; Fail "Web console did not start. Full log: logs\client.log" }
    if (PortBusy $ClientPort) { break }
    Start-Sleep -Seconds 1
  }

  Write-Host "`nReady. " -ForegroundColor Green -NoNewline
  Write-Host "Open  http://localhost:$ClientPort"
  Write-Host "Server API docs: http://localhost:$ServerPort/swagger-ui.html"
  Write-Host "Press Ctrl+C to stop.`n"

  while (-not $server.HasExited -and -not $client.HasExited) { Start-Sleep -Seconds 2 }
  Fail "One of the two stopped unexpectedly. Check logs\server.log and logs\client.log."
}
finally {
  foreach ($p in @($client, $server)) {
    if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  }
  Write-Host "`n==> Stopped." -ForegroundColor Cyan
}
