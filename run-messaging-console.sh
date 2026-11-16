#!/usr/bin/env bash
# ============================================================================
#  Build the Messaging Console server and run it together with the client
#  in one terminal (macOS and Linux).
#
#  Steps:
#    1. Build the server jar   (server/mvnw package, tests skipped)
#    2. Run, at the same time:
#         server   java -jar server/target/messaging-service-*.jar   (port 8080)
#         client   npm run dev   in client/                        (port 5173)
#       Every output line is prefixed with [server] or [client]. Ctrl+C stops
#       both, and when one of them exits the other is stopped too.
#
#  Usage:
#    ./run-messaging-console.sh                  build, then run server + client
#    ./run-messaging-console.sh --no-build       skip the build; run the last built jar
#    ./run-messaging-console.sh --tests          run the server tests during the build
#    ./run-messaging-console.sh --no-client      run only the server
#    ./run-messaging-console.sh --no-server      run only the client
#    ./run-messaging-console.sh --mock           client in mock mode (no server calls)
#    ./run-messaging-console.sh --port 9090      server on another port; the client
#                                                follows it
#    ./run-messaging-console.sh --help
#
#  Options can be combined, e.g.  --no-build --port 9090
#  First time on this machine? Run ./init.sh once to set up the prerequisites.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD

# shellcheck source=scripts/tools-env.sh
. scripts/tools-env.sh

MIN_JAVA=21
MIN_NODE=22.12
NO_BUILD=0
RUN_TESTS=0
RUN_SERVER=1
RUN_CLIENT=1
MOCK=0
PORT=8080
CLIENT_PORT=5173

usage() {
  cat <<'EOF'
Build the Messaging Console server, then run the server and the client together
in this terminal. Output lines are prefixed with [server] and [client].
Ctrl+C stops both.

Usage: ./run-messaging-console.sh [options]

  --no-build     Skip the server build; run the last built jar
  --tests        Run the server tests during the build
  --no-client    Run only the server
  --no-server    Run only the client
  --mock         Client in mock mode: no calls to the server
  --port N       Server on port N instead of 8080; the client follows it
  --help         Show this help

First time on this machine? Run ./init.sh once to set up the prerequisites.
EOF
}

# --- Options ----------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --no-build)  NO_BUILD=1 ;;
    --tests)     RUN_TESTS=1 ;;
    --no-client) RUN_CLIENT=0 ;;
    --no-server) RUN_SERVER=0 ;;
    --mock)      MOCK=1 ;;
    --port)
      [ -n "${2:-}" ] || { echo "[ERROR] --port needs a number, e.g. --port 9090"; exit 1; }
      PORT=$2; shift ;;
    --help|-h)   usage; exit 0 ;;
    *) echo "[ERROR] Unknown option: $1"; echo; echo 'Run "./run-messaging-console.sh --help" for the options.'; exit 1 ;;
  esac
  shift
done

case "$PORT" in ''|*[!0-9]*) echo "[ERROR] --port must be a number, got \"$PORT\"."; exit 1 ;; esac
{ [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; } || { echo "[ERROR] --port must be between 1 and 65535."; exit 1; }
[ "$RUN_SERVER$RUN_CLIENT" != "00" ] || { echo "[ERROR] --no-server and --no-client together leave nothing to run."; exit 1; }
[ -f server/mvnw ] || { echo "[ERROR] Run this script from the messaging-console repository root."; exit 1; }

SERVER_DESC="server (http://localhost:$PORT)";        [ "$RUN_SERVER" = 0 ] && SERVER_DESC="(skipped)"
CLIENT_DESC="client (http://localhost:$CLIENT_PORT)"; [ "$MOCK" = 1 ] && CLIENT_DESC="$CLIENT_DESC, mock mode"
[ "$RUN_CLIENT" = 0 ] && CLIENT_DESC="(skipped)"
BUILD_DESC="server jar, tests skipped"; [ "$RUN_TESTS" = 1 ] && BUILD_DESC="server jar, with tests"
[ "$NO_BUILD" = 1 ] && BUILD_DESC="(skipped, --no-build)"
[ "$RUN_SERVER" = 0 ] && BUILD_DESC="(skipped, no server)"

echo
echo "Repo root : $ROOT"
echo "Build     : $BUILD_DESC"
echo "Server    : $SERVER_DESC"
echo "Client    : $CLIENT_DESC"
echo

# --- Prerequisites (init.sh sets them up; this only checks) ------------------
command -v node >/dev/null 2>&1 \
  && node -e "const [a,b]=process.versions.node.split('.').map(Number),[x,y]='$MIN_NODE'.split('.').map(Number);process.exit(a>x||(a===x&&b>=y)?0:1)" \
  || { echo "[ERROR] Node.js $MIN_NODE or newer is needed. Run ./init.sh first."; exit 1; }
if [ "$RUN_SERVER" = 1 ]; then
  jv=$(command -v java >/dev/null 2>&1 && java -version 2>&1 | awk -F'"' '/version/ {split($2, v, "."); print (v[1] == "1" ? v[2] : v[1]); exit}' || echo 0)
  [ "${jv:-0}" -ge "$MIN_JAVA" ] || { echo "[ERROR] Java $MIN_JAVA or newer is needed for the server. Run ./init.sh first."; exit 1; }
fi
if [ ! -f node_modules/concurrently/dist/bin/index.js ]; then
  echo "[setup] Installing the top-level packages (npm install)..."
  npm install --no-fund --no-audit --loglevel=error || { echo "[ERROR] npm install failed."; exit 1; }
fi
if [ "$RUN_CLIENT" = 1 ] && [ ! -d client/node_modules ]; then
  echo "[setup] Installing the client's packages (npm install in client)..."
  npm install --prefix client --no-fund --no-audit --loglevel=error || { echo "[ERROR] npm install in client failed."; exit 1; }
fi
if [ "$RUN_CLIENT" = 1 ] && [ ! -f client/.env ]; then
  cp client/.env.example client/.env
  echo "[setup] Created client/.env from client/.env.example."
fi

# --- 1. Build the server -----------------------------------------------------
JAR=""
if [ "$RUN_SERVER" = 1 ]; then
  if [ "$NO_BUILD" = 0 ]; then
    TEST_FLAG=-DskipTests; [ "$RUN_TESTS" = 1 ] && TEST_FLAG=""
    echo "\$ server/mvnw -B -ntp $TEST_FLAG package"
    rc=0; (cd server && ./mvnw -B -ntp $TEST_FLAG package) || rc=$?
    [ "$rc" = 0 ] || { echo; echo "[ERROR] Server build failed (exit $rc). Aborting."; exit "$rc"; }
  fi
  JAR=$(ls server/target/messaging-service-*.jar 2>/dev/null | grep -v -- '-plain.jar' | head -n 1 || true)
  [ -n "$JAR" ] || { echo "[ERROR] No server jar in server/target. Run without --no-build to build it."; exit 1; }
  JAR=$(basename "$JAR")
fi

# --- 2. Run server and client together ---------------------------------------
port_busy() { (echo >"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
[ "$RUN_SERVER" = 1 ] && port_busy "$PORT" && echo "[WARNING] Port $PORT is already in use; the server will fail to start. Stop the other program first."
[ "$RUN_CLIENT" = 1 ] && port_busy "$CLIENT_PORT" && echo "[WARNING] Port $CLIENT_PORT is already in use; the client will fail to start. Stop the other program first."

# Settings for the children. Real environment variables win over .env files
# for both Spring Boot and Vite, so these apply to this run only.
[ "$RUN_SERVER" = 1 ] && export SERVER_PORT="$PORT"
[ "$RUN_CLIENT" = 1 ] && export DEV_PROXY_TARGET="http://localhost:$PORT"
[ "$MOCK" = 1 ] && export VITE_USE_MOCK_API=true

NAMES=(); COLORS=(); CMDS=()
if [ "$RUN_SERVER" = 1 ]; then NAMES+=(server); COLORS+=(blue);  CMDS+=("cd server && java -jar target/$JAR"); fi
if [ "$RUN_CLIENT" = 1 ]; then NAMES+=(client); COLORS+=(green); CMDS+=("npm run dev --prefix client -- --port $CLIENT_PORT --strictPort"); fi
NAMES_CSV=$(IFS=,; echo "${NAMES[*]}")
COLORS_CSV=$(IFS=,; echo "${COLORS[*]}")

echo "\$ concurrently --names $NAMES_CSV --kill-others ${CMDS[*]}"
echo "  Ctrl+C stops everything."
[ "$RUN_SERVER$RUN_CLIENT" = 11 ] && echo '  The server needs a few seconds to start; until then the client shows "cannot reach the server". Click Refresh.'
echo
exec node "$ROOT/node_modules/concurrently/dist/bin/index.js" --names "$NAMES_CSV" --prefix-colors "$COLORS_CSV" --kill-others "${CMDS[@]}"
