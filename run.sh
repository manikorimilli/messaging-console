#!/usr/bin/env bash
# Builds and starts the server and the web console together.
# Open http://localhost:5173 when it says "Ready". Press Ctrl+C to stop both.
#
#   ./run.sh
#   SERVER_PORT=9090 CLIENT_PORT=3000 ./run.sh    (other ports)
set -euo pipefail
cd "$(dirname "$0")"

SERVER_PORT=${SERVER_PORT:-8080}
CLIENT_PORT=${CLIENT_PORT:-5173}
LOGS=logs

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\n\033[1;31mStopped:\033[0m %s\n' "$*" >&2; exit 1; }
port_busy() { (echo >"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

[ -d client/node_modules ] && [ -f client/.env ] || fail "Run ./init.sh first (one time)."
port_busy "$SERVER_PORT" && fail "Port $SERVER_PORT is in use. Close the program using it (maybe an earlier ./run.sh), then try again."
port_busy "$CLIENT_PORT" && fail "Port $CLIENT_PORT is in use. Close the program using it (maybe an earlier ./run.sh), then try again."
mkdir -p "$LOGS"

say "Building the server"
(cd server && ./mvnw -q -DskipTests package) >"$LOGS/server-build.log" 2>&1 \
  || { tail -n 30 "$LOGS/server-build.log"; fail "Server build failed. Full log: $LOGS/server-build.log"; }
JAR=$(ls server/target/*.jar 2>/dev/null | grep -v -- '-plain.jar' | head -n 1)
[ -n "$JAR" ] || fail "Server build made no jar file. Full log: $LOGS/server-build.log"

say "Building the web console"
npm run build --prefix client >"$LOGS/client-build.log" 2>&1 \
  || { tail -n 30 "$LOGS/client-build.log"; fail "Web console build failed. Full log: $LOGS/client-build.log"; }

SERVER_PID=""; CLIENT_PID=""
stop() {
  trap - EXIT INT TERM
  [ -n "$CLIENT_PID" ] && kill "$CLIENT_PID" 2>/dev/null || true
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
  wait 2>/dev/null || true
  echo; say "Stopped."
}
trap stop EXIT INT TERM

say "Starting the server (log: $LOGS/server.log)"
# Run from server/ so registered providers stay in server/db.json.
(cd server && exec java -jar "../$JAR" --server.port="$SERVER_PORT") >"$LOGS/server.log" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 90); do
  kill -0 "$SERVER_PID" 2>/dev/null || { tail -n 30 "$LOGS/server.log"; fail "Server did not start. Full log: $LOGS/server.log"; }
  node -e "fetch('http://localhost:$SERVER_PORT/actuator/health').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))" && break
  sleep 1
done
node -e "fetch('http://localhost:$SERVER_PORT/actuator/health').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))" \
  || fail "Server did not answer within 90 seconds. Full log: $LOGS/server.log"

say "Starting the web console (log: $LOGS/client.log)"
# The console forwards /api to the server started above, whatever client/.env says.
(cd client && DEV_PROXY_TARGET="http://localhost:$SERVER_PORT" exec npx vite preview --port "$CLIENT_PORT" --strictPort) >"$LOGS/client.log" 2>&1 &
CLIENT_PID=$!

for _ in $(seq 1 30); do
  kill -0 "$CLIENT_PID" 2>/dev/null || { tail -n 30 "$LOGS/client.log"; fail "Web console did not start. Full log: $LOGS/client.log"; }
  port_busy "$CLIENT_PORT" && break
  sleep 1
done

printf '\n\033[1;32mReady.\033[0m Open  http://localhost:%s\n' "$CLIENT_PORT"
printf 'Server API docs: http://localhost:%s/swagger-ui.html\n' "$SERVER_PORT"
printf 'Press Ctrl+C to stop.\n\n'

# Keep running until Ctrl+C or until either one exits.
while kill -0 "$SERVER_PID" 2>/dev/null && kill -0 "$CLIENT_PID" 2>/dev/null; do sleep 2; done
fail "One of the two stopped unexpectedly. Check $LOGS/server.log and $LOGS/client.log."
