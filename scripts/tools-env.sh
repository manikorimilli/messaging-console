# Sourced by init.sh and run.sh. Puts Java and Node.js from .tools/ (downloaded by
# init.sh when the computer has no suitable version) first on the PATH.
TOOLS_DIR="$PWD/.tools"

if [ -x "$TOOLS_DIR/node/bin/node" ]; then
  PATH="$TOOLS_DIR/node/bin:$PATH"
fi

for home in "$TOOLS_DIR/java" "$TOOLS_DIR/java/Contents/Home"; do
  if [ -x "$home/bin/java" ]; then
    export JAVA_HOME="$home"
    PATH="$home/bin:$PATH"
    break
  fi
done

export PATH
hash -r

# No "new npm version available" notices for customers.
export NPM_CONFIG_UPDATE_NOTIFIER=false
