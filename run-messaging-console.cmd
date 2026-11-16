@echo off
rem ============================================================================
rem  Build the Messaging Console server and run it together with the client
rem  in one terminal.
rem
rem  Steps:
rem    1. Build the server jar   (server\mvnw.cmd package, tests skipped)
rem    2. Run, at the same time:
rem         server   java -jar server\target\messaging-service-*.jar   (port 8080)
rem         client   npm run dev   in client\                        (port 5173)
rem       Every output line is prefixed with [server] or [client]. Ctrl+C stops
rem       both, and when one of them exits the other is stopped too.
rem
rem  Usage:
rem    run-messaging-console.cmd                  build, then run server + client
rem    run-messaging-console.cmd --no-build       skip the build; run the last built jar
rem    run-messaging-console.cmd --tests          run the server tests during the build
rem    run-messaging-console.cmd --no-client      run only the server
rem    run-messaging-console.cmd --no-server      run only the client
rem    run-messaging-console.cmd --mock           client in mock mode (no server calls)
rem    run-messaging-console.cmd --port 9090      server on another port; the client
rem                                               follows it
rem    run-messaging-console.cmd --help
rem
rem  Options can be combined, e.g.  --no-build --port 9090
rem  First time on this machine? Run init.cmd once to install the prerequisites.
rem
rem  After Ctrl+C, Windows may ask "Terminate batch job (Y/N)?". Both processes
rem  are already stopped by then; either answer is fine.
rem ============================================================================
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "ROOT=%~dp0"

set "MIN_JAVA=21"
set "MIN_NODE_MAJOR=22"
set "MIN_NODE_MINOR=12"
set "NO_BUILD=0"
set "RUN_TESTS=0"
set "RUN_SERVER=1"
set "RUN_CLIENT=1"
set "MOCK=0"
set "PORT=8080"
set "CLIENT_PORT=5173"

rem ---------------------------------------------------------------------------
rem  Options
rem ---------------------------------------------------------------------------
:parse
if "%~1"=="" goto :parsed
if /i "%~1"=="--no-build"  (set "NO_BUILD=1"   & shift & goto :parse)
if /i "%~1"=="--tests"     (set "RUN_TESTS=1"  & shift & goto :parse)
if /i "%~1"=="--no-client" (set "RUN_CLIENT=0" & shift & goto :parse)
if /i "%~1"=="--no-server" (set "RUN_SERVER=0" & shift & goto :parse)
if /i "%~1"=="--mock"      (set "MOCK=1"       & shift & goto :parse)
if /i "%~1"=="--port" goto :parse_port
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="-h"     goto :usage
if /i "%~1"=="/?"     goto :usage
echo [ERROR] Unknown option: %~1
echo.
goto :usage_error

:parse_port
if "%~2"=="" goto :port_missing
set "PORT=%~2"
shift
shift
goto :parse
:port_missing
echo [ERROR] --port needs a number, e.g. --port 9090
exit /b 1

:usage
echo Build the Messaging Console server, then run the server and the client together
echo in this terminal. Output lines are prefixed with [server] and [client].
echo Ctrl+C stops both.
echo.
echo Usage: run-messaging-console.cmd [options]
echo.
echo   --no-build     Skip the server build; run the last built jar
echo   --tests        Run the server tests during the build
echo   --no-client    Run only the server
echo   --no-server    Run only the client
echo   --mock         Client in mock mode: no calls to the server
echo   --port N       Server on port N instead of 8080; the client follows it
echo   --help         Show this help
echo.
echo First time on this machine? Run init.cmd once to install the prerequisites.
exit /b 0
:usage_error
echo Run "run-messaging-console.cmd --help" for the options.
exit /b 1

:parsed
set /a "PORT_NUM=%PORT%" 2>nul
if not "%PORT_NUM%"=="%PORT%" (echo [ERROR] --port must be a number, got "%PORT%".& exit /b 1)
if %PORT% LSS 1 (echo [ERROR] --port must be between 1 and 65535.& exit /b 1)
if %PORT% GTR 65535 (echo [ERROR] --port must be between 1 and 65535.& exit /b 1)
if "%RUN_SERVER%%RUN_CLIENT%"=="00" (echo [ERROR] --no-server and --no-client together leave nothing to run.& exit /b 1)
if not exist "server\mvnw.cmd" (echo [ERROR] Run this script from the messaging-console repository root.& exit /b 1)

set "SERVER_DESC=server (http://localhost:%PORT%)"
if "%RUN_SERVER%"=="0" set "SERVER_DESC=(skipped)"
set "CLIENT_DESC=client (http://localhost:%CLIENT_PORT%)"
if "%MOCK%"=="1" set "CLIENT_DESC=!CLIENT_DESC!, mock mode"
if "%RUN_CLIENT%"=="0" set "CLIENT_DESC=(skipped)"
set "BUILD_DESC=server jar, tests skipped"
if "%RUN_TESTS%"=="1" set "BUILD_DESC=server jar, with tests"
if "%NO_BUILD%"=="1" set "BUILD_DESC=(skipped, --no-build)"
if "%RUN_SERVER%"=="0" set "BUILD_DESC=(skipped, no server)"

echo.
echo Repo root : %ROOT%
echo Build     : %BUILD_DESC%
echo Server    : %SERVER_DESC%
echo Client    : %CLIENT_DESC%
echo.

rem ---------------------------------------------------------------------------
rem  Prerequisites (init.cmd installs them; this only checks)
rem ---------------------------------------------------------------------------
call :check_node || exit /b 1
if "%RUN_SERVER%"=="1" (call :select_java || exit /b 1)
call :ensure_packages || exit /b 1

rem ---------------------------------------------------------------------------
rem  1. Build the server
rem ---------------------------------------------------------------------------
if "%RUN_SERVER%"=="0" goto :launch
if "%NO_BUILD%"=="1" goto :find_jar
set "TEST_FLAG=-DskipTests"
if "%RUN_TESTS%"=="1" set "TEST_FLAG="
echo $ server\mvnw.cmd -B -ntp %TEST_FLAG% package
pushd server
call .\mvnw.cmd -B -ntp %TEST_FLAG% package
set "RC=!errorlevel!"
popd
if not "!RC!"=="0" (
    echo.
    echo [ERROR] Server build failed ^(exit !RC!^). Aborting.
    exit /b !RC!
)

:find_jar
set "JAR="
for %%f in ("server\target\messaging-service-*.jar") do (
    if /i "%%~xf"==".jar" set "JAR=%%~nxf"
)
if not defined JAR (
    echo [ERROR] No server jar in server\target. Run without --no-build to build it.
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem  2. Run server and client together
rem ---------------------------------------------------------------------------
:launch
if "%RUN_SERVER%"=="1" call :check_port %PORT% server
if "%RUN_CLIENT%"=="1" call :check_port %CLIENT_PORT% client

rem Settings for the children. Real environment variables win over .env files
rem for both Spring Boot and Vite, so these apply to this run only.
if "%RUN_SERVER%"=="1" set "SERVER_PORT=%PORT%"
if "%RUN_CLIENT%"=="1" set "DEV_PROXY_TARGET=http://localhost:%PORT%"
if "%MOCK%"=="1" set "VITE_USE_MOCK_API=true"

set "NAMES="
set "COLORS="
set "CMDS="
if "%RUN_SERVER%"=="1" (
    set "NAMES=server"
    set "COLORS=blue"
    set CMDS="cd /d server && java -jar target\!JAR!"
)
if "%RUN_CLIENT%"=="1" (
    if defined NAMES (set "NAMES=!NAMES!,client" & set "COLORS=!COLORS!,green") else (set "NAMES=client" & set "COLORS=green")
    set CMDS=!CMDS! "npm run dev --prefix client"
)

echo $ concurrently --names %NAMES% --kill-others !CMDS!
echo   Ctrl+C stops everything.
if "%RUN_SERVER%"=="1" if "%RUN_CLIENT%"=="1" echo   The server needs a few seconds to start; until then the client shows "cannot reach the server". Click Refresh.
echo.
node "%ROOT%node_modules\concurrently\dist\bin\index.js" --names %NAMES% --prefix-colors %COLORS% --kill-others !CMDS!
exit /b %errorlevel%


rem ============================================================================
rem  Helpers
rem ============================================================================

:check_node
set "NODE_MAJOR=0"
set "NODE_MINOR=0"
where node >nul 2>&1 || goto :node_missing
for /f "tokens=1-2 delims=v." %%a in ('node -v 2^>nul') do (
    set "NODE_MAJOR=%%a"
    set "NODE_MINOR=%%b"
)
if !NODE_MAJOR! GTR %MIN_NODE_MAJOR% exit /b 0
if !NODE_MAJOR! EQU %MIN_NODE_MAJOR% if !NODE_MINOR! GEQ %MIN_NODE_MINOR% exit /b 0
:node_missing
echo [ERROR] Node.js %MIN_NODE_MAJOR%.%MIN_NODE_MINOR% or newer is needed. Run init.cmd, then open a new terminal.
exit /b 1

rem Picks a Java 21+ for this run: JAVA_HOME first, then the java on PATH.
rem Sets JAVA_HOME and puts its bin first on PATH, so mvnw.cmd and java agree.
:select_java
set "PICKED="
if defined JAVA_HOME (
    call :java_major_at "!JAVA_HOME!"
    if !FOUND_MAJOR! GEQ %MIN_JAVA% set "PICKED=!JAVA_HOME!"
)
if not defined PICKED (
    where java >nul 2>&1 && for /f "tokens=1,* delims==" %%a in ('java -XshowSettings:properties -version 2^>^&1 ^| findstr /c:"java.home"') do (
        for /f "tokens=*" %%t in ("%%b") do (
            call :java_major_at "%%t"
            if !FOUND_MAJOR! GEQ %MIN_JAVA% set "PICKED=%%t"
        )
    )
)
if not defined PICKED (
    echo [ERROR] Java %MIN_JAVA% or newer is needed for the server. Run init.cmd, then open a new terminal.
    exit /b 1
)
set "JAVA_HOME=!PICKED!"
set "PATH=!PICKED!\bin;!PATH!"
exit /b 0

rem Sets FOUND_MAJOR to the Java major version in folder %1 (0 if none).
:java_major_at
set "FOUND_MAJOR=0"
if not exist "%~1\bin\java.exe" exit /b 0
set "JV="
for /f "tokens=3" %%v in ('call "%~1\bin\java.exe" -version 2^>^&1 ^| findstr /i /c:" version "') do if not defined JV set "JV=%%~v"
if not defined JV exit /b 0
for /f "tokens=1,2 delims=.-+_" %%a in ("!JV!") do (
    if "%%a"=="1" (set "FOUND_MAJOR=%%b") else set "FOUND_MAJOR=%%a"
)
exit /b 0

:ensure_packages
if not exist "%ROOT%node_modules\concurrently\dist\bin\index.js" (
    echo [setup] Installing the top-level packages ^(npm install^)...
    call npm install --no-fund --no-audit || (echo [ERROR] npm install failed.& exit /b 1)
)
if "%RUN_CLIENT%"=="1" if not exist "client\node_modules" (
    echo [setup] Installing the client's packages ^(npm install in client^)...
    call npm install --prefix client --no-fund --no-audit || (echo [ERROR] npm install in client failed.& exit /b 1)
)
if "%RUN_CLIENT%"=="1" if not exist "client\.env" (
    copy /y "client\.env.example" "client\.env" >nul
    echo [setup] Created client\.env from client\.env.example.
)
exit /b 0

:check_port
netstat -ano -p tcp | findstr /r /c:":%~1  *.*LISTENING" >nul
if not errorlevel 1 echo [WARNING] Port %~1 is already in use; the %~2 will fail to start. Stop the other program first.
exit /b 0
