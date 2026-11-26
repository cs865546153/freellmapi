#!/bin/bash
# local-dev-setup.sh
# https://github.com/cs865546153/freellmapi
# Quick local dev bootstrap — avoids common pitfalls

set -euo pipefail

echo "=== FreeLLMAPI Local Dev Setup ==="

# 1. Node.js (prebuilt binary — avoids Homebrew source builds)
if ! command -v node &> /dev/null; then
  echo "[1/4] Installing Node 22 (prebuilt)..."
  curl -fsSL https://nodejs.org/dist/v22.17.0/node-v22.17.0-darwin-arm64.tar.gz | tar xzv -C /tmp
  mkdir -p "$HOME/.local/share/nodejs"
  cp -R /tmp/node-v22.17.0-darwin-arm64/* "$HOME/.local/share/nodejs/"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.local/share/nodejs/bin/node" "$HOME/.local/bin/node"
  ln -sf "$HOME/.local/share/nodejs/bin/npm" "$HOME/.local/bin/npm"
  export PATH="$HOME/.local/bin:$PATH"
else
  echo "[1/4] Node already installed: $(node --version)"
fi

# 2. npm dependencies
echo "[2/4] Installing npm packages..."
npm install

# 3. Generate .env with ENCRYPTION_KEY
echo "[3/4] Generating ENCRYPTION_KEY..."
KEY="$(node -e 'console.log(require("crypto").randomBytes(32).toString("hex"))')"
printf "ENCRYPTION_KEY=%s\nPORT=3001\n" "$KEY" > .env
echo "  → .env written (ENCRYPTION_KEY + PORT)"

# 4. Start server
echo "[4/4] Starting server (npm run dev)..."
echo "  Dashboard: http://localhost:5173"
echo "  API:       http://127.0.0.1:3001/v1"
echo "  Unified key: copy from Keys page after first run"
npm run dev