#!/usr/bin/env bash
# One-time setup. Safe to run again.
#
#   ./init.sh
#
# Uses Java 21+ and Node.js 22.12+ if the computer already has them. If not, it
# downloads them into the .tools folder inside this project (from adoptium.net
# and nodejs.org). It installs nothing on the system and never asks for a password.
set -euo pipefail
cd "$(dirname "$0")"

JAVA_MIN=21
NODE_MIN=22.12

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[32mOK\033[0m  %s\n' "$*"; }
fail() { printf '\n\033[1;31mSetup stopped:\033[0m %s\n' "$*" >&2; exit 1; }

# shellcheck source=scripts/tools-env.sh
. scripts/tools-env.sh

# --- What computer is this? -------------------------------------------------
case "$(uname -s)" in
  Linux)  NODE_OS=linux;  JAVA_OS=linux ;;
  Darwin) NODE_OS=darwin; JAVA_OS=mac ;;
  *) fail "This script runs on macOS and Linux. On Windows, use WSL (Ubuntu)." ;;
esac
case "$(uname -m)" in
  x86_64|amd64)  NODE_ARCH=x64;   JAVA_ARCH=x64 ;;
  aarch64|arm64) NODE_ARCH=arm64; JAVA_ARCH=aarch64 ;;
  *) fail "Unsupported processor: $(uname -m)." ;;
esac

# --- Helpers ----------------------------------------------------------------
download() { # url file
  if command -v curl >/dev/null 2>&1; then curl -fL --progress-bar -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q --show-progress -O "$2" "$1"
  else fail "Neither curl nor wget is installed. Install one of them, then run ./init.sh again."
  fi
}
fetch() { # url -> stdout
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"; else wget -qO- "$1"; fi
}
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
  node -e "const [a,b]=process.versions.node.split('.').map(Number),[x,y]='$NODE_MIN'.split('.').map(Number);process.exit(a>x||(a===x&&b>=y)?0:1)"
}

mkdir -p "$TOOLS_DIR"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- Node.js ----------------------------------------------------------------
say "Checking Node.js $NODE_MIN or newer"
if ! node_ok; then
  echo "    Not found. Downloading Node.js 22 into .tools/ ..."
  base=https://nodejs.org/dist/latest-v22.x
  fetch "$base/SHASUMS256.txt" > "$TMP/node.sums" || fail "Could not reach nodejs.org. Check the internet connection."
  file=$(grep -o "node-v[0-9.]*-$NODE_OS-$NODE_ARCH\.tar\.gz" "$TMP/node.sums" | head -n 1)
  [ -n "$file" ] || fail "No Node.js download found for $NODE_OS-$NODE_ARCH."
  download "$base/$file" "$TMP/$file"
  [ "$(sha256 "$TMP/$file")" = "$(grep " $file\$" "$TMP/node.sums" | cut -d' ' -f1)" ] \
    || fail "The Node.js download is damaged. Run ./init.sh again."
  rm -rf "$TOOLS_DIR/node" && mkdir -p "$TOOLS_DIR/node"
  tar -xzf "$TMP/$file" -C "$TOOLS_DIR/node" --strip-components=1
  . scripts/tools-env.sh
  node_ok || fail "Node.js could not be set up in .tools/node."
fi
ok "Node.js $(node -v)"

# --- Java -------------------------------------------------------------------
say "Checking Java $JAVA_MIN or newer"
if [ "$(java_major)" -lt "$JAVA_MIN" ]; then
  echo "    Not found. Downloading Java $JAVA_MIN into .tools/ (about 200 MB) ..."
  api="https://api.adoptium.net/v3/assets/latest/$JAVA_MIN/hotspot?architecture=$JAVA_ARCH&image_type=jdk&os=$JAVA_OS&vendor=eclipse"
  fetch "$api" > "$TMP/java.json" || fail "Could not reach adoptium.net. Check the internet connection."
  read -r link sum < <(node -e "const p=JSON.parse(require('fs').readFileSync(process.argv[1]))[0].binary.package;console.log(p.link,p.checksum)" "$TMP/java.json") \
    || fail "No Java download found for $JAVA_OS-$JAVA_ARCH."
  download "$link" "$TMP/java.tar.gz"
  [ "$(sha256 "$TMP/java.tar.gz")" = "$sum" ] || fail "The Java download is damaged. Run ./init.sh again."
  rm -rf "$TOOLS_DIR/java" && mkdir -p "$TOOLS_DIR/java"
  tar -xzf "$TMP/java.tar.gz" -C "$TOOLS_DIR/java" --strip-components=1
  . scripts/tools-env.sh
  [ "$(java_major)" -ge "$JAVA_MIN" ] || fail "Java could not be set up in .tools/java."
fi
ok "$(java -version 2>&1 | head -n 1)"

# --- App --------------------------------------------------------------------
say "Installing the web console's packages"
npm ci --prefix client --no-audit --no-fund --loglevel=error >/dev/null
npm ci --no-audit --no-fund --loglevel=error >/dev/null
ok "client/node_modules"

say "Creating settings files"
if [ ! -f client/.env ]; then
  sed 's/^VITE_USE_MOCK_API=.*/VITE_USE_MOCK_API=false/' client/.env.example > client/.env
  ok "client/.env created"
else
  ok "client/.env already exists, left as is"
fi

say "Downloading the server's libraries and building it (first time: 1-3 minutes)"
chmod +x server/mvnw run.sh
(cd server && ./mvnw -q -DskipTests package)
ok "server built"

printf '\n\033[1;32mSetup complete.\033[0m Start the app with:  ./run.sh\n\n'
