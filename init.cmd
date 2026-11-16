@echo off
rem ============================================================================
rem  Messaging Console - one-time setup for Windows
rem
rem  Checks the prerequisites, installs any that are missing (with winget), then
rem  installs the packages and builds the server and the client once. When it
rem  ends with "Setup complete", "npm run dev" starts the application.
rem
rem    init.cmd           check, install what is missing, then build
rem    init.cmd /check    only report what is installed; change nothing
rem
rem  Prerequisites: Git, Java JDK 21 or newer, Node.js 22.12 or newer.
rem  Maven is not needed: the server includes its own (server\mvnw.cmd).
rem ============================================================================
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "MIN_JAVA=21"
set "MIN_NODE_MAJOR=22"
set "MIN_NODE_MINOR=12"
set "CHECK_ONLY=0"
set "MISSING=0"
set "FAIL_MSG="
if /i "%~1"=="/check" set "CHECK_ONLY=1"
if /i "%~1"=="--check" set "CHECK_ONLY=1"

if not exist "server\mvnw.cmd" (
    echo [ERROR] Run init.cmd from the messaging-console repository root.
    exit /b 1
)

echo.
echo === Messaging Console setup ===
echo.
echo --- Prerequisites ---

call :ensure_git  || goto :fail
call :ensure_java || goto :fail
call :ensure_node || goto :fail

if "%CHECK_ONLY%"=="1" goto :check_summary

echo.
echo --- Project ---
call :project_setup || goto :fail
call :check_port 8080 server
call :check_port 5173 client

echo.
echo === Setup complete ===
echo Start the application with:   npm run dev
echo Then open:                    http://localhost:5173
echo.
echo Open a new terminal first if init.cmd installed anything, so it picks up the new PATH.
exit /b 0

:check_summary
echo.
if "%MISSING%"=="0" (
    echo All prerequisites are installed. Run init.cmd without /check to install packages and build.
    exit /b 0
)
echo Some prerequisites are missing or too old. Run init.cmd without /check to install them.
exit /b 2

:fail
echo.
echo [FAILED] !FAIL_MSG!
exit /b 1


rem ============================================================================
rem  Git
rem ============================================================================
:ensure_git
call :git_version
if defined GIT_VER goto :git_ok
echo [MISSING] Git not found.
call :install Git.Git || exit /b 1
if "%CHECK_ONLY%"=="1" exit /b 0
call :git_version
if defined GIT_VER goto :git_ok
set "FAIL_MSG=Git is still not available. Install it from https://git-scm.com, open a new terminal and run init.cmd again."
exit /b 1
:git_ok
echo [OK]      Git !GIT_VER!
exit /b 0

:git_version
set "GIT_VER="
where git >nul 2>&1 || exit /b 0
for /f "tokens=3" %%v in ('git --version 2^>nul') do set "GIT_VER=%%v"
exit /b 0


rem ============================================================================
rem  Java JDK 21+
rem ============================================================================
:ensure_java
call :java_version
if !JAVA_MAJOR! GEQ %MIN_JAVA% goto :java_ok
rem PATH may find an older java first while Java 21+ is already installed (for
rem example after an earlier run of init.cmd): use that one instead of installing.
call :find_jdk
if defined FOUND_JDK goto :java_ok
if "!JAVA_MAJOR!"=="0" (echo [MISSING] Java JDK not found.) else echo [TOO OLD] Java !JAVA_VER! found; the server needs Java %MIN_JAVA% or newer.
call :install EclipseAdoptium.Temurin.21.JDK || exit /b 1
if "%CHECK_ONLY%"=="1" exit /b 0
call :java_version
if !JAVA_MAJOR! GEQ %MIN_JAVA% goto :java_ok
rem An older Java is still first on PATH: put the new JDK in front for this run.
call :find_jdk
if defined FOUND_JDK goto :java_ok
set "FAIL_MSG=Java %MIN_JAVA% or newer is still not available. Install it manually, open a new terminal and run init.cmd again."
exit /b 1
:java_ok
echo [OK]      Java !JAVA_VER!
call :fix_java_home
exit /b 0

rem Looks for an installed Java 21+ in JAVA_HOME, then in the usual JDK folders.
rem If found, puts it first on PATH for this run and sets FOUND_JDK, JAVA_VER and JAVA_MAJOR.
:find_jdk
set "FOUND_JDK="
if defined JAVA_HOME (
    call :java_major_at "!JAVA_HOME!"
    if !HOME_MAJOR! GEQ %MIN_JAVA% set "FOUND_JDK=!JAVA_HOME!"
)
for /d %%d in ("%ProgramFiles%\Eclipse Adoptium\jdk-*" "%ProgramFiles%\Java\jdk-*" "%ProgramFiles%\Microsoft\jdk-*") do (
    if not defined FOUND_JDK (
        call :java_major_at "%%~d"
        if !HOME_MAJOR! GEQ %MIN_JAVA% set "FOUND_JDK=%%~d"
    )
)
if not defined FOUND_JDK exit /b 0
set "PATH=!FOUND_JDK!\bin;!PATH!"
call :java_version
exit /b 0

rem Sets JAVA_VER (e.g. 21.0.5) and JAVA_MAJOR (e.g. 21, or 0 when java is not found)
rem for the first java on PATH.
:java_version
set "JAVA_MAJOR=0"
set "JAVA_VER="
where java >nul 2>&1 || exit /b 0
for /f "tokens=3" %%a in ('java -version 2^>^&1 ^| findstr /i /c:" version "') do if not defined JAVA_VER set "JAVA_VER=%%~a"
if not defined JAVA_VER exit /b 0
for /f "tokens=1,2 delims=.-+_" %%a in ("!JAVA_VER!") do (
    if "%%a"=="1" (set "JAVA_MAJOR=%%b") else set "JAVA_MAJOR=%%a"
)
exit /b 0

rem mvnw.cmd runs %JAVA_HOME%\bin\java.exe when JAVA_HOME is set, so JAVA_HOME must
rem not point to an older JDK. If it does, point it at the Java 21+ found above
rem (for this run, and saved for the user with setx).
:fix_java_home
set "JH="
for /f "tokens=1,* delims==" %%a in ('java -XshowSettings:properties -version 2^>^&1 ^| findstr /c:"java.home"') do set "JH=%%b"
if not defined JH exit /b 0
for /f "tokens=*" %%t in ("!JH!") do set "JH=%%t"
if not defined JAVA_HOME (
    set "JAVA_HOME=!JH!"
    exit /b 0
)
if /i "!JAVA_HOME!"=="!JH!" exit /b 0
call :java_major_at "!JAVA_HOME!"
if !HOME_MAJOR! GEQ %MIN_JAVA% exit /b 0
if "%CHECK_ONLY%"=="1" (
    echo [TO FIX]  JAVA_HOME points to "!JAVA_HOME!", which is not Java %MIN_JAVA%+.
    set "MISSING=1"
    exit /b 0
)
echo [FIX]     JAVA_HOME pointed to "!JAVA_HOME!", which is not Java %MIN_JAVA%+.
echo           Setting JAVA_HOME to "!JH!" for your user account.
set "JAVA_HOME=!JH!"
setx JAVA_HOME "!JH!" >nul
exit /b 0

rem Sets HOME_MAJOR to the Java major version found in folder %1 (0 if none).
:java_major_at
if not exist "%~1\bin\java.exe" (
    set "HOME_MAJOR=0"
    exit /b 0
)
setlocal
set "PATH=%~1\bin;%PATH%"
call :java_version
endlocal & set "HOME_MAJOR=%JAVA_MAJOR%"
exit /b 0


rem ============================================================================
rem  Node.js 22.12+ (with npm)
rem ============================================================================
:ensure_node
call :node_version
call :node_ok && goto :node_good
if "!NODE_MAJOR!"=="0" (echo [MISSING] Node.js not found.) else echo [TOO OLD] Node.js !NODE_VER! found; the client needs %MIN_NODE_MAJOR%.%MIN_NODE_MINOR% or newer.
call :install OpenJS.NodeJS.LTS || exit /b 1
if "%CHECK_ONLY%"=="1" exit /b 0
call :node_version
call :node_ok && goto :node_good
set "FAIL_MSG=Node.js %MIN_NODE_MAJOR%.%MIN_NODE_MINOR% or newer is still not first on PATH. If you use nvm, run 'nvm install lts' and 'nvm use lts'; otherwise open a new terminal and run init.cmd again."
exit /b 1
:node_good
set "NPM_VER="
for /f "delims=" %%v in ('npm -v 2^>nul') do set "NPM_VER=%%v"
if not defined NPM_VER (
    set "FAIL_MSG=Node.js is installed but npm was not found. Reinstall Node.js from https://nodejs.org."
    exit /b 1
)
echo [OK]      Node.js !NODE_VER!, npm !NPM_VER!
exit /b 0

rem Sets NODE_VER (e.g. 22.12.0), NODE_MAJOR and NODE_MINOR (0 when node is not found).
:node_version
set "NODE_MAJOR=0"
set "NODE_MINOR=0"
set "NODE_VER="
where node >nul 2>&1 || exit /b 0
for /f "tokens=1-3 delims=v." %%a in ('node -v 2^>nul') do (
    set "NODE_MAJOR=%%a"
    set "NODE_MINOR=%%b"
    set "NODE_VER=%%a.%%b.%%c"
)
exit /b 0

:node_ok
if !NODE_MAJOR! GTR %MIN_NODE_MAJOR% exit /b 0
if !NODE_MAJOR! EQU %MIN_NODE_MAJOR% if !NODE_MINOR! GEQ %MIN_NODE_MINOR% exit /b 0
exit /b 1


rem ============================================================================
rem  Installing with winget
rem ============================================================================
rem Installs (or upgrades) winget package %1. In /check mode, only records that
rem something is missing.
:install
if "%CHECK_ONLY%"=="1" (
    set "MISSING=1"
    exit /b 0
)
where winget >nul 2>&1
if errorlevel 1 (
    set "FAIL_MSG=winget is not available. Install 'App Installer' from the Microsoft Store, or install %~1 manually, then run init.cmd again."
    exit /b 1
)
echo           Installing %~1 with winget. Accept the Windows prompt if one appears...
winget install --id %~1 -e --source winget --silent --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
    rem Already installed in an older version: winget install refuses, upgrade instead.
    winget upgrade --id %~1 -e --source winget --silent --accept-source-agreements --accept-package-agreements
)
call :refresh_path
exit /b 0

rem Reloads PATH from the registry so tools installed above are found without
rem opening a new terminal.
:refresh_path
for /f "usebackq delims=" %%p in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%p"
exit /b 0


rem ============================================================================
rem  Project: packages, settings, build
rem ============================================================================
:project_setup
echo [1/5] Installing the top-level packages (npm install)...
call npm install --no-fund --no-audit
if errorlevel 1 (
    set "FAIL_MSG=npm install failed. Check your internet connection or npm proxy settings."
    exit /b 1
)

echo [2/5] Installing the client's packages (npm run setup)...
call npm run setup -- --no-fund --no-audit
if errorlevel 1 (
    set "FAIL_MSG=Installing the client's packages failed. Check your internet connection or npm proxy settings."
    exit /b 1
)

echo [3/5] Client settings file...
if exist "client\.env" (
    echo           client\.env already exists; left unchanged.
) else (
    copy /y "client\.env.example" "client\.env" >nul
    echo           Created client\.env from client\.env.example: live data from http://localhost:8080.
    echo           Set VITE_USE_MOCK_API=true in it to try the console without the server.
)

echo [4/5] Building the server (downloads Maven and libraries the first time)...
pushd server
call .\mvnw.cmd -B -ntp -DskipTests compile
set "RC=!errorlevel!"
popd
if not "!RC!"=="0" (
    set "FAIL_MSG=The server build failed. See the Maven output above."
    exit /b 1
)

echo [5/5] Building the client...
call npm run build --prefix client
if errorlevel 1 (
    set "FAIL_MSG=The client build failed. See the output above."
    exit /b 1
)
exit /b 0

:check_port
netstat -ano -p tcp | findstr /r /c:":%~1  *.*LISTENING" >nul
if not errorlevel 1 echo [WARNING] Port %~1, used by the %~2, is already in use. Stop that program before "npm run dev".
exit /b 0
