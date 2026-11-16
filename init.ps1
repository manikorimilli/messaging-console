# One-time setup on Windows. Safe to run again.
#
#   powershell -ExecutionPolicy Bypass -File init.ps1
#
# Uses Java 21+ and Node.js 22.12+ if the computer already has them. If not, it
# downloads them into the .tools folder inside this project (from adoptium.net
# and nodejs.org). It installs nothing on the system and needs no admin rights.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with a progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-Location $PSScriptRoot

$JavaMin = 21
$NodeMin = [version]'22.12'

function Say($m)  { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    OK  $m" -ForegroundColor Green }
function Fail($m) { Write-Host "`nSetup stopped: $m" -ForegroundColor Red; exit 1 }

. "$PSScriptRoot\scripts\tools-env.ps1"

$arm = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
$NodeArch = if ($arm) { 'arm64' } else { 'x64' }
$JavaArch = if ($arm) { 'aarch64' } else { 'x64' }
$Force = $env:MC_FORCE_DOWNLOAD -eq '1'   # for testing: ignore Java/Node already on the computer

function Download($url, $file) {
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    & curl.exe -fL --progress-bar -o $file $url
    if ($LASTEXITCODE -ne 0) { Fail "Download failed: $url" }
  } else {
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $file
  }
}
function Unzip($zip, $dest) {
  New-Item -ItemType Directory -Force $dest | Out-Null
  if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
    & tar.exe -xf $zip -C $dest
    if ($LASTEXITCODE -ne 0) { Fail "Could not unpack $zip" }
  } else {
    Expand-Archive -Path $zip -DestinationPath $dest -Force
  }
}
# Moves the single folder inside $tmpDir to $target.
function MoveInto($tmpDir, $target) {
  $inner = Get-ChildItem $tmpDir -Directory | Select-Object -First 1
  if (Test-Path $target) { Remove-Item -Recurse -Force $target }
  Move-Item $inner.FullName $target
}
function JavaMajor {
  if (-not (Get-Command java -ErrorAction SilentlyContinue)) { return 0 }
  $line = (cmd /c "java -version 2>&1" | Select-Object -First 1)
  if ($line -match '"(\d+)(\.(\d+))?') { if ($Matches[1] -eq '1') { return [int]$Matches[3] } else { return [int]$Matches[1] } }
  return 0
}
function NodeOk {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) { return $false }
  $v = (& node -v).TrimStart('v')
  return ([version]($v -replace '^(\d+\.\d+).*', '$1')) -ge $NodeMin
}

New-Item -ItemType Directory -Force $ToolsDir | Out-Null
$Tmp = Join-Path $env:TEMP ("mc-setup-" + [guid]::NewGuid())
New-Item -ItemType Directory $Tmp | Out-Null

try {
  # --- Node.js --------------------------------------------------------------
  Say "Checking Node.js $NodeMin or newer"
  if ($Force -or -not (NodeOk)) {
    Write-Host "    Downloading Node.js 22 into .tools\ ..."
    $base = 'https://nodejs.org/dist/latest-v22.x'
    $sums = (Invoke-WebRequest -UseBasicParsing "$base/SHASUMS256.txt").Content
    $line = ($sums -split "`n") | Where-Object { $_ -match "node-v[\d.]+-win-$NodeArch\.zip$" } | Select-Object -First 1
    if (-not $line) { Fail "No Node.js download found for win-$NodeArch." }
    $hash, $file = $line.Trim() -split '\s+'
    Download "$base/$file" "$Tmp\$file"
    if ((Get-FileHash "$Tmp\$file" -Algorithm SHA256).Hash -ne $hash.ToUpper()) { Fail "The Node.js download is damaged. Run setup again." }
    Unzip "$Tmp\$file" "$Tmp\node"
    MoveInto "$Tmp\node" (Join-Path $ToolsDir 'node')
    . "$PSScriptRoot\scripts\tools-env.ps1"
    if (-not (NodeOk)) { Fail "Node.js could not be set up in .tools\node." }
  }
  Ok "Node.js $(& node -v)"

  # --- Java -----------------------------------------------------------------
  Say "Checking Java $JavaMin or newer"
  if ($Force -or (JavaMajor) -lt $JavaMin) {
    Write-Host "    Downloading Java $JavaMin into .tools\ (about 200 MB) ..."
    $api = "https://api.adoptium.net/v3/assets/latest/$JavaMin/hotspot?architecture=$JavaArch&image_type=jdk&os=windows&vendor=eclipse"
    $pkg = (Invoke-RestMethod $api)[0].binary.package
    if (-not $pkg) { Fail "No Java download found for windows-$JavaArch." }
    Download $pkg.link "$Tmp\java.zip"
    if ((Get-FileHash "$Tmp\java.zip" -Algorithm SHA256).Hash -ne $pkg.checksum.ToUpper()) { Fail "The Java download is damaged. Run setup again." }
    Unzip "$Tmp\java.zip" "$Tmp\java"
    MoveInto "$Tmp\java" (Join-Path $ToolsDir 'java')
    . "$PSScriptRoot\scripts\tools-env.ps1"
    if ((JavaMajor) -lt $JavaMin) { Fail "Java could not be set up in .tools\java." }
  }
  Ok (cmd /c "java -version 2>&1" | Select-Object -First 1)

  # --- App ------------------------------------------------------------------
  Say "Installing the web console's packages"
  & npm.cmd ci --prefix client --no-audit --no-fund --loglevel=error | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "Installing the web console's packages failed." }
  & npm.cmd ci --no-audit --no-fund --loglevel=error | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "Installing packages failed." }
  Ok "client\node_modules"

  Say "Creating settings files"
  if (-not (Test-Path 'client\.env')) {
    (Get-Content 'client\.env.example') -replace '^VITE_USE_MOCK_API=.*', 'VITE_USE_MOCK_API=false' | Set-Content 'client\.env'
    Ok "client\.env created"
  } else {
    Ok "client\.env already exists, left as is"
  }

  Say "Downloading the server's libraries and building it (first time: 1-3 minutes)"
  Push-Location server
  & .\mvnw.cmd -q -DskipTests package
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { Fail "Server build failed." }
  Ok "server built"
}
finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Host "`nSetup complete. " -ForegroundColor Green -NoNewline
Write-Host "Start the app: double-click run.cmd, or run .\run.ps1`n"
