#!/usr/bin/env bash
# ============================================================================
#  Messaging Console - one-time setup for macOS and Linux
#
#  Checks the prerequisites, sets up any that are missing, then installs the
#  packages and builds the server and the client once. When it ends with
#  "Setup complete", ./run-messaging-console.sh starts the application.
#
#    ./init.sh           check, set up what is missing, then build
#    ./init.sh --check   only report what is installed; change nothing
#
#  Prerequisites: Java JDK 21 or newer, Node.js 22.12 or newer.
#  If one is missing, it is downloaded into the .tools folder of this project
#  (from adoptium.net and nodejs.org): nothing is installed on the system and
#  no password is needed. Maven is not needed: the server includes its own
#  (server/mvnw).
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

MIN_JAVA=21
MIN_NODE=22.12
CHECK_ONLY=0
MISSING=0
case "${1:-}" in --check|/check) CHECK_ONLY=1 ;; esac

[ -f server/mvnw ] || { echo "[ERROR] Run init.sh from the messaging-console repository root."; exit 1; }

# shellcheck source=scripts/tools-env.sh
. scripts/tools-env.sh

fail() { echo; echo "[FAILED] $*"; exit 1; }

case "$(uname -s)" in
  Linux)  NODE_OS=linux;  JAVA_OS=linux ;;
  Darwin) NODE_OS=darwin; JAVA_OS=mac ;;
  *) fail "init.sh runs on macOS and Linux. On Windows, run init.cmd." ;;
esac
case "$(uname -m)" in
  x86_64|amd64)  NODE_ARCH=x64;   JAVA_ARCH=x64 ;;
  aarch64|arm64) NODE_ARCH=arm64; JAVA_ARCH=aarch64 ;;
  *) fail "Unsupported processor: $(uname -m)." ;;
esac

download() { # url file
  if command -v curl >/dev/null 2>&1; then curl -fL --progress-bar -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q --show-progress -O "$2" "$1"
  else fail "Neither curl nor wget is installed. Install one of them, then run init.sh again."
  fi
}
fetch() { if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"; else wget -qO- "$1"; fi; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}
java_major() {
  command -v java >/dev/null 2>&1 || { echo 0; return; }
  local v
  v=$(java -version 2>&1 | awk -F'"' '/version/ {split($2, v, "."); print (v[1] == "1" ? v[2] : v[1]); exit}')
  echo "${v:-0}"
}
node_ok() {
  command -v node >/dev/null 2>&1 || return 1
  node -e "const [a,b]=process.versions.node.split('.').map(Number),[x,y]='$MIN_NODE'.split('.').map(Number);process.exit(a>x||(a===x&&b>=y)?0:1)"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo
echo "=== Messaging Console setup ==="
echo
echo "--- Prerequisites ---"

# --- Node.js 22.12+ (with npm) ----------------------------------------------
if node_ok; then
  echo "[OK]      Node.js $(node -v | tr -d v), npm $(npm -v)"
else
  if command -v node >/dev/null 2>&1; then
    echo "[TOO OLD] Node.js $(node -v | tr -d v) found; the client needs $MIN_NODE or newer."
  else
    echo "[MISSING] Node.js not found."
  fi
  MISSING=1
  if [ "$CHECK_ONLY" = 0 ]; then
    echo "          Downloading Node.js 22 into .tools/ ..."
    base=https://nodejs.org/dist/latest-v22.x
    fetch "$base/SHASUMS256.txt" > "$TMP/node.sums" || fail "Could not reach nodejs.org. Check your internet connection."
    file=$(grep -o "node-v[0-9.]*-$NODE_OS-$NODE_ARCH\.tar\.gz" "$TMP/node.sums" | head -n 1)
    [ -n "$file" ] || fail "No Node.js download found for $NODE_OS-$NODE_ARCH."
    download "$base/$file" "$TMP/$file"
    [ "$(sha256 "$TMP/$file")" = "$(grep " $file\$" "$TMP/node.sums" | cut -d' ' -f1)" ] \
      || fail "The Node.js download is damaged. Run init.sh again."
    rm -rf "$TOOLS_DIR/node" && mkdir -p "$TOOLS_DIR/node"
    tar -xzf "$TMP/$file" -C "$TOOLS_DIR/node" --strip-components=1
    . scripts/tools-env.sh
    node_ok || fail "Node.js could not be set up in .tools/node."
    echo "[OK]      Node.js $(node -v | tr -d v), npm $(npm -v)"
  fi
fi

# --- Java JDK 21+ -----------------------------------------------------------
if [ "$(java_major)" -ge "$MIN_JAVA" ]; then
  echo "[OK]      Java $(java -version 2>&1 | awk -F'"' '/version/ {print $2; exit}')"
else
  if command -v java >/dev/null 2>&1; then
    echo "[TOO OLD] Java $(java -version 2>&1 | awk -F'"' '/version/ {print $2; exit}') found; the server needs Java $MIN_JAVA or newer."
  else
    echo "[MISSING] Java JDK not found."
  fi
  MISSING=1
  if [ "$CHECK_ONLY" = 0 ]; then
    echo "          Downloading Java $MIN_JAVA into .tools/ (about 200 MB) ..."
    node_ok || fail "Node.js is needed to read the Java download list. Run init.sh again."
    api="https://api.adoptium.net/v3/assets/latest/$MIN_JAVA/hotspot?architecture=$JAVA_ARCH&image_type=jdk&os=$JAVA_OS&vendor=eclipse"
    fetch "$api" > "$TMP/java.json" || fail "Could not reach adoptium.net. Check your internet connection."
    read -r link sum < <(node -e "const p=JSON.parse(require('fs').readFileSync(process.argv[1]))[0].binary.package;console.log(p.link,p.checksum)" "$TMP/java.json") \
      || fail "No Java download found for $JAVA_OS-$JAVA_ARCH."
    download "$link" "$TMP/java.tar.gz"
    [ "$(sha256 "$TMP/java.tar.gz")" = "$sum" ] || fail "The Java download is damaged. Run init.sh again."
    rm -rf "$TOOLS_DIR/java" && mkdir -p "$TOOLS_DIR/java"
    tar -xzf "$TMP/java.tar.gz" -C "$TOOLS_DIR/java" --strip-components=1
    . scripts/tools-env.sh
    [ "$(java_major)" -ge "$MIN_JAVA" ] || fail "Java could not be set up in .tools/java."
    echo "[OK]      Java $(java -version 2>&1 | awk -F'"' '/version/ {print $2; exit}')"
  fi
fi

if [ "$CHECK_ONLY" = 1 ]; then
  echo
  if [ "$MISSING" = 0 ]; then
    echo "All prerequisites are installed. Run ./init.sh without --check to install packages and build."
    exit 0
  fi
  echo "Some prerequisites are missing or too old. Run ./init.sh without --check to set them up."
  exit 2
fi

# --- Project: packages, settings, build -------------------------------------
echo
echo "--- Project ---"
echo "[1/5] Installing the top-level packages (npm install)..."
npm install --no-fund --no-audit --loglevel=error || fail "npm install failed. Check your internet connection or npm proxy settings."

echo "[2/5] Installing the client's packages (npm run setup)..."
npm run setup --silent -- --no-fund --no-audit --loglevel=error || fail "Installing the client's packages failed. Check your internet connection or npm proxy settings."

echo "[3/5] Client settings file..."
if [ -f client/.env ]; then
  echo "          client/.env already exists; left unchanged."
else
  cp client/.env.example client/.env
  echo "          Created client/.env from client/.env.example: live data from http://localhost:8080."
  echo "          Set VITE_USE_MOCK_API=true in it to try the console without the server."
fi

echo "[4/5] Building the server (downloads Maven and libraries the first time)..."
chmod +x server/mvnw run-messaging-console.sh
(cd server && ./mvnw -B -ntp -q -DskipTests compile) || fail "The server build failed. See the Maven output above."

echo "[5/5] Building the client..."
build_out=$(npm run build --silent --prefix client 2>&1) || { echo "$build_out" | tail -n 20; fail "The client build failed. See the output above."; }

port_busy() { (echo >"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
port_busy 8080 && echo "[WARNING] Port 8080, used by the server, is already in use. Stop that program before ./run-messaging-console.sh."
port_busy 5173 && echo "[WARNING] Port 5173, used by the client, is already in use. Stop that program before ./run-messaging-console.sh."

echo
echo "=== Setup complete ==="
echo "Start the application with:   ./run-messaging-console.sh"
echo "Then open:                    http://localhost:5173"
echo
