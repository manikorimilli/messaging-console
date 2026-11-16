#!/usr/bin/env bash
# Downloads Messaging Console into ./messaging-console and runs its setup.
# Needs only curl or wget: if git is installed it clones, otherwise it downloads
# the code as an archive from GitHub. Safe to run again.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/manikorimilli/messaging-console/main/get.sh || wget -qO- https://raw.githubusercontent.com/manikorimilli/messaging-console/main/get.sh)"
set -euo pipefail

REPO=manikorimilli/messaging-console
BRANCH=${MESSAGING_CONSOLE_BRANCH:-main}
DIR=messaging-console

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\n\033[1;31mStopped:\033[0m %s\n' "$*" >&2; exit 1; }

download() { # url file
  if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
  else fail "Neither curl nor wget is installed."
  fi
}

if [ -f ./init.sh ] && [ -f ./get.sh ]; then
  DIR=.
  say "Already inside the app folder, using it"
elif [ -f "$DIR/init.sh" ]; then
  say "Found $DIR here already, using it"
elif [ -e "$DIR" ]; then
  fail "A '$DIR' folder already exists here but is not this app. Move it away or run this from another folder."
elif command -v git >/dev/null 2>&1; then
  say "Downloading the code (git)"
  git clone --quiet --branch "$BRANCH" "https://github.com/$REPO.git" "$DIR"
else
  say "Downloading the code"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  download "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" "$tmp/code.tar.gz" \
    || fail "Could not download the code from GitHub. Check the internet connection."
  mkdir -p "$DIR"
  tar -xzf "$tmp/code.tar.gz" -C "$DIR" --strip-components=1
fi

cd "$DIR"
chmod +x init.sh run.sh
./init.sh

printf 'To start the app:\n\n    cd %s\n    ./run.sh\n\n' "$PWD"
