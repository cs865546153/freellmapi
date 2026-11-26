# 本地开发 —— 常见坑与一键设置
> **最后更新：** 2026-11-26 | **排错指南见文末**

---

## 目录

1. [坑点](#坑点) — 2026-11-26 特定发现的问题
   - [1.1 Node.js 安装](#11-nodejs-安装)
   - [1.2 npm install / 依赖解析](#12-npm-install--依赖解析)
   - [1.3 ENCRYPTION_KEY 设置](#13-encryption_key-设置)
   - [1.4 opencode auth.json 位置](#14-opencode-authjson-位置)
   - [1.5 用 Docker Compose 替代](#15-用-docker-compose-替代)
2. [一键设置脚本](#一键设置脚本)
3. [排错](#排错)

---

## 坑点

### 1.1 Node.js 安装

**问题：** macOS 14+ 上 Homebrew 装 Node 会走源码编译（cmake、openssl、python 全从源码构建），耗时 30-70 分钟，经常因网络/CPU 失败。

**修复：** 用官方预编译包
```bash
curl -fsSL https://nodejs.org/dist/v22.17.0/node-v22.17.0-darwin-arm64.tar.gz | tar xzv -C /tmp
cp -R /tmp/node-v22.17.0-darwin-arm64 \
  /Users/$(whoami)/.local/share/nodejs/
ln -sf /Users/$(whoami)/.local/share/nodejs/bin/node \
  /Users/$(whoami)/.local/bin/node
ln -sf /Users/$(whoami)/.local/share/nodejs/bin/npm \
  /Users/$(whoami)/.local/bin/npm
```

或直接用 `nvm`：
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
nvm install 22
```

---

### 1.2 npm install / 依赖解析

**问题：** 有些系统会有 `npm warn deprecated` / 漏洞警告。如果原生模块（better-sqlite3、esbuild）编译失败，服务起不来。

**修复：**
```bash
npm install
# 原生模块失败时检查：
uname -a
# macOS 14+ 装构建工具：
xcode-select --install
brew install cmake
```

**npm 缓存问题：** 如果 `npm install` 静默失败：
```bash
npm cache clean --force
rm -rf node_modules
npm install
```

---

### 1.3 ENCRYPTION_KEY 设置

**问题：** 忘了设 `ENCRYPTION_KEY` 会导致：
- “.env 缺少 key” 警告
- 数据库不加密
- key 明文存储（仅开发环境）
- Docker：容器重启后读不了 DB

**修复：** 生成 32 字节 hex key 存进 `.env`：
```bash
KEY="$(node -e 'console.log(require("crypto").randomBytes(32).toString("hex"))')"
printf "ENCRYPTION_KEY=%s\nPORT=3001\n" "$KEY" > .env
```

**千万别提交进 Git：** 确认 `.env` 已被忽略（`git check-ignore .env` 应返回 `.env`）。

**Docker：** 别在 docker-compose.env 里设 `ENCRYPTION_KEY`，只用 `.env` 文件。

---

### 1.4 opencode auth.json 位置

**问题：** 装完 opencode 后，启动脚本把数据目录重定向到 `~/.local/share/opencode-cli`（不是 `~/.local/share/opencode`）。放错 auth.json 路径，统一 key 读不到。

**错误路径（别用）：**
- `~/.config/opencode/opencode.json` — OK，这是 config
- `~/.local/share/opencode/auth.json` — **错的**，key 不在这里读

**正确 auth.json 位置：**
- `~/.local/share/opencode-cli/opencode/auth.json` — **key 放这里**

**写入 key：**
```bash
cat > ~/.local/share/opencode-cli/opencode/auth.json <<EOF
{
  "freellmapi": {
    "type": "api",
    "key": "<你的统一key>"
  }
}
EOF
```

获取统一 key：先启动服务，从 dashboard 读：
```bash
curl http://127.0.0.1:3001/api/settings/api-key \
  -H "Authorization: Bearer <dashboard-session-token>"
```

**改完 auth.json 后重启 opencode** 或重新选 `freellmapi/auto` 模型。

---

### 1.5 用 Docker Compose 替代

**问题：** 如果你在 Node 安装 + npm 上花了 30+ 分钟，那你忽略了明显的“一键”路径——Docker。

**解决：** 永远把 Docker Compose 作为首选安装方式。它处理：
- 服务器 + dashboard 一个容器
- SQLite 用命名卷持久化
- 自动日志
- 目标机不用装 Node/npm（只要 Docker Desktop）
- 自动生成的 ENCRYPTION_KEY（通常不用手填）

**Docker Compose 命令：**
```bash
git clone https://github.com/your-username/freellmapi.git && cd freellmapi
ENCRYPTION_KEY="$(openssl rand -hex 32)"
printf "ENCRYPTION_KEY=%s\nPORT=3001\n" "$ENCRYPTION_KEY" > .env
docker compose up -d
```

**排错：** `docker compose up` 失败时：
- macOS：确认 Docker Desktop 在跑（`docker --version`）
- 全部：确认 `usermod -a -G docker $(whoami)` 或查防火墙

---

## 一键设置脚本

> 把 `docs/zh-cn/local-dev-setup.sh` 放进你的仓库做自包含引导。

```bash
#!/bin/bash
# local-dev-setup.sh
# https://github.com/your-username/freellmapi

set -euo pipefail

echo "=== FreeLLMAPI 本地开发设置 ==="

# Node.js 安装（预编译）
if ! command -v node &> /dev/null; then
  echo "安装 Node 22..."
  curl -fsSL https://nodejs.org/dist/v22.17.0/node-v22.17.0-darwin-arm64.tar.gz | tar xzv -C /tmp
  ln -sf /tmp/node-v22.17.0-darwin-arm64/bin/node "$HOME/.local/share/nodejs/bin/node"
  ln -sf /tmp/node-v22.17.0-darwin-arm64/bin/npm "$HOME/.local/share/nodejs/bin/npm"
else
  echo "Node 已安装: $(node --version)"
fi

# 依赖
echo "安装 npm 包..."
npm install

# 生成 .env
echo "生成 ENCRYPTION_KEY..."
KEY="$(node -e 'console.log(require("crypto").randomBytes(32).toString("hex"))')"
printf "ENCRYPTION_KEY=%s\nPORT=3001\n" "$KEY" > .env

# 启动服务
echo "启动服务..."
npm run dev
```

在 README 加说明：
```markdown
## 本地设置（快捷）

```bash
./docs/zh-cn/local-dev-setup.sh && npm run dev
```
然后打开 http://localhost:5173，点“Keys” 页，完事。
```

---

## 排错

| 症状 | 可能原因 | 修复 |
|------|----------|------|
| opencode 报 `Invalid API key` | auth.json 位置错了（`~/.local/share/opencode/auth.json` 而非 `~/.local/share/opencode-cli/opencode/auth.json`） | 把 key 放对位置；重启 opencode |
| 服务起了但连不上 | 3001 端口被占 | `lsof -i :3001` → 杀掉或换 `PORT=3002` |
| `npm install` 报原生模块错 | 缺 cmake / python | `brew install cmake` + `python@3.11` |
| dashboard 连不上 API | 浏览器防火墙或 CORS | 临时关 `localhost:3001` 防火墙 |
| docker 报 `ENCRYPTION_KEY` 缺失 | 容器在 .env 挂载前被杀 | 用 `docker compose up`（别用 `docker run`） |
| docker 日志 `exit 1` | 主机网络权限 / Apple Silicon | 装最新 Docker Desktop |

---

## 相关

- [Docker Compose 安装文档](https://github.com/tashfeenahmed/freellmapi/blob/main/docs/en/install/01-install.md)
- [OpenCode 设置（cli + auth）](https://github.com/tashfeenahmed/freellmapi/tree/main/cli/src/tools.ts#L280-L300)
- [Provider key 指南](https://github.com/tashfeenahmed/freellmapi/tree/main/server/src/providers)

---

## 贡献者

感谢 [freellmapi](https://github.com/tashfeenahmed/freellmapi) 维护者的 OpenCode 兼容网关。