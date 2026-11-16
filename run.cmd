@echo off
rem Double-click to start Messaging Console on Windows. Runs setup first if needed.
cd /d "%~dp0"
if not exist "client\node_modules" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0init.ps1"
  if errorlevel 1 goto failed
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1"
if errorlevel 1 goto failed
exit /b 0
:failed
echo.
pause
exit /b 1
