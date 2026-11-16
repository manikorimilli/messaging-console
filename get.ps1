# Downloads Messaging Console into .\messaging-console and runs its setup (Windows).
# If git is installed it clones, otherwise it downloads the code as a zip from GitHub.
# Safe to run again.
#
#   irm https://raw.githubusercontent.com/manikorimilli/messaging-console/main/get.ps1 | iex
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $repo = 'manikorimilli/messaging-console'
  $branch = if ($env:MESSAGING_CONSOLE_BRANCH) { $env:MESSAGING_CONSOLE_BRANCH } else { 'main' }
  $useGit = (Get-Command git -ErrorAction SilentlyContinue) -and ($env:MC_NO_GIT -ne '1')

  function Say($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

  # Where to put the app: the current folder, unless it is a Windows system folder
  # (an Administrator PowerShell starts in C:\Windows\system32) or not writable.
  function Writable($path) {
    $probe = Join-Path $path ("mc-write-test-" + [guid]::NewGuid())
    try { New-Item -ItemType Directory $probe -ErrorAction Stop | Out-Null; Remove-Item $probe -Force; return $true }
    catch { return $false }
  }
  $here = (Get-Location).Path
  $systemDirs = @($env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
  $inSystem = $systemDirs | Where-Object { $here.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }
  if ($inSystem -or -not (Writable $here)) {
    $here = $HOME
    Set-Location $here
    Say "Using your user folder: $here"
  }
  $dir = Join-Path $here 'messaging-console'

  if ((Test-Path '.\init.ps1') -and (Test-Path '.\get.ps1')) {
    $dir = (Get-Location).Path
    Say "Already inside the app folder, using it"
  } elseif (Test-Path (Join-Path $dir 'init.ps1')) {
    Say "Found messaging-console here already, using it"
  } elseif (Test-Path $dir) {
    Write-Host "`nStopped: a 'messaging-console' folder already exists here but is not this app. Move it away or run this from another folder." -ForegroundColor Red
    return
  } elseif ($useGit) {
    Say "Downloading the code (git)"
    & git clone --quiet --branch $branch "https://github.com/$repo.git" $dir
    if ($LASTEXITCODE -ne 0) { Write-Host "`nStopped: git clone failed." -ForegroundColor Red; return }
  } else {
    Say "Downloading the code"
    $tmp = Join-Path $env:TEMP ("mc-get-" + [guid]::NewGuid())
    New-Item -ItemType Directory $tmp | Out-Null
    try {
      Invoke-WebRequest -UseBasicParsing "https://codeload.github.com/$repo/zip/refs/heads/$branch" -OutFile "$tmp\code.zip"
      Expand-Archive "$tmp\code.zip" "$tmp\code" -Force
      Move-Item (Get-ChildItem "$tmp\code" -Directory | Select-Object -First 1).FullName $dir
    } finally {
      Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
  }

  $ps = (Get-Process -Id $PID).Path
  & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'init.ps1')
  if ($LASTEXITCODE -ne 0) { return }

  Write-Host "To start the app:`n"
  Write-Host "    cd `"$dir`""
  Write-Host "    .\run.cmd`n"
}
