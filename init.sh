#!/usr/bin/env bash
# One-time setup. Installs Java 21 and Node.js 22 if they are missing, then
# downloads everything the app needs. Safe to run again.
#
#   ./init.sh
set -euo pipefail
cd "$(dirname "$0")"

JAVA_MIN=21
NODE_MIN=22.12

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[32mOK\033[0m  %s\n' "$*"; }
fail() { printf '\n\033[1;31mSetup stopped:\033[0m %s\n' "$*" >&2; exit 1; }

# Java major version, or 0 if Java is not installed.
java_major() {
  command -v java >/dev/null 2>&1 || { echo 0; return; }
  local v
  v=$(java -version 2>&1 | awk -F'"' '/version/ {split($2, v, "."); print (v[1] == "1" ? v[2] : v[1]); exit}')
  echo "${v:-0}"
}

# True if Node.js is at least NODE_MIN.
node_ok() {
  command -v node >/dev/null 2>&1 || return 1
  node -e "const [a,b]=process.versions.node.split('.').map(Number),[x,y]='$NODE_MIN'.split('.').map(Number);process.exit(a>x||(a===x&&b>=y)?0:1)"
}

SUDO=""
[ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

install_java() {
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null 2>&1 || fail "Homebrew is needed to install Java. Install it from https://brew.sh, then run ./init.sh again."
      brew install --cask temurin@21 ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update -qq
        $SUDO apt-get install -y -qq openjdk-21-jdk-headless \
          || fail "Could not install Java 21 with apt. Install it from https://adoptium.net, then run ./init.sh again."
      elif command -v dnf >/dev/null 2>&1; then
        $SUDO dnf install -y -q java-21-openjdk-devel
      else
        fail "Install Java $JAVA_MIN from https://adoptium.net, then run ./init.sh again."
      fi ;;
    *) fail "Install Java $JAVA_MIN from https://adoptium.net, then run ./init.sh again." ;;
  esac
}

install_node() {
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null 2>&1 || fail "Homebrew is needed to install Node.js. Install it from https://brew.sh, then run ./init.sh again."
      brew install node@22 && brew link --overwrite --force node@22 ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get install -y -qq curl ca-certificates
        curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO bash -
        $SUDO apt-get install -y -qq nodejs
      elif command -v dnf >/dev/null 2>&1; then
        $SUDO dnf install -y -q nodejs
      else
        fail "Install Node.js 22 from https://nodejs.org, then run ./init.sh again."
      fi ;;
    *) fail "Install Node.js 22 from https://nodejs.org, then run ./init.sh again." ;;
  esac
}

say "Checking Java $JAVA_MIN or newer"
if [ "$(java_major)" -lt "$JAVA_MIN" ]; then
  echo "    Not found. Installing Java $JAVA_MIN..."
  install_java
  hash -r
  [ "$(java_major)" -ge "$JAVA_MIN" ] || fail "Java $JAVA_MIN was installed but is not the default. Open a new terminal and run ./init.sh again."
fi
ok "$(java -version 2>&1 | head -1)"

say "Checking Node.js $NODE_MIN or newer"
if ! node_ok; then
  echo "    Not found. Installing Node.js 22..."
  install_node
  hash -r
  node_ok || fail "Node.js 22 was installed but is not the default. Open a new terminal and run ./init.sh again."
fi
ok "Node.js $(node -v)"

say "Installing the web console's packages"
npm ci --prefix client --no-audit --no-fund --loglevel=error
npm ci --no-audit --no-fund --loglevel=error
ok "client/node_modules"

say "Creating settings files"
if [ ! -f client/.env ]; then
  sed 's/^VITE_USE_MOCK_API=.*/VITE_USE_MOCK_API=false/' client/.env.example > client/.env
  ok "client/.env created"
else
  ok "client/.env already exists, left as is"
fi

say "Downloading the server's libraries and building it (first time takes 1-2 minutes)"
chmod +x server/mvnw run.sh
(cd server && ./mvnw -q -DskipTests package)
ok "server built"

printf '\n\033[1;32mSetup complete.\033[0m Start the app with:  ./run.sh\n\n'
