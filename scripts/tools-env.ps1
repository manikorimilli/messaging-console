# Dot-sourced by init.ps1 and run.ps1. Puts Java and Node.js from .tools\ (downloaded
# by init.ps1 when the computer has no suitable version) first on the PATH.
$ToolsDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.tools'

$nodeDir = Join-Path $ToolsDir 'node'
if (Test-Path (Join-Path $nodeDir 'node.exe')) {
  $env:Path = "$nodeDir;$env:Path"
}

$javaDir = Join-Path $ToolsDir 'java'
if (Test-Path (Join-Path $javaDir 'bin\java.exe')) {
  $env:JAVA_HOME = $javaDir
  $env:Path = "$javaDir\bin;$env:Path"
}

# No "new npm version available" notices for customers.
$env:NPM_CONFIG_UPDATE_NOTIFIER = 'false'
