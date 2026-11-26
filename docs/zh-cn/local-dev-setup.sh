#!/bin/bash
# local-dev-setup.sh
# https://github.com/cs865546153/freellmapi
# 本地开发一键引导 — 避开常见坑

set -euo pipefail

echo "=== FreeLLMAPI 本地开发一键设置 ==="

# 1. Node.js (官方预编译包 — 避开 Homebrew 源码编译)
if ! command -v node &> /dev/null; then
  echo "[1/4] 安装 Node 22（预编译）..."
  curl -fsSL https://nodejs.org/dist/v22.17.0/node-v22.17.0-darwin-arm64.tar.gz | tar xzv -C /tmp
  mkdir -p "$HOME/.local/share/nodejs"
  cp -R /tmp/node-v22.17.0-darwin-arm64/* "$HOME/.local/share/nodejs/"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.local/share/nodejs/bin/node" "$HOME/.local/bin/node"
  ln -sf "$HOME/.local/share/nodejs/bin/npm" "$HOME/.local/bin/npm"
  export PATH="$HOME/.local/bin:$PATH"
else
  echo "[1/4] Node 已安装: $(node --version)"
fi

# 2. npm 依赖
echo "[2/4] 安装 npm 包..."
npm install

# 3. 生成 .env（含 ENCRYPTION_KEY）
echo "[3/4] 生成 ENCRYPTION_KEY..."
KEY="$(node -e 'console.log(require("crypto").randomBytes(32).toString("hex"))')"
printf "ENCRYPTION_KEY=%s\nPORT=3001\n" "$KEY" > .env
echo "  → .env 已写入（ENCRYPTION_KEY + PORT）"

# 4. 启动服务
echo "[4/4] 启动服务（npm run dev）..."
echo "  Dashboard: http://localhost:5173"
echo "  API:       http://127.0.0.1:3001/v1"
echo "  统一 key: 首次运行后在 Keys 页面复制"
npm run dev