# Local Development — Common Pitfalls and One-Click Setup
> **Last updated:** 2026-11-26 | **Troubleshooting:** see below

---

## Table of Contents

1. [Pitfalls](#pitfalls) — 2026-11-26 specific issues found
   - [1.1 Node.js installation](#11-nodejs-installation)
   - [1.2 npm install / dependency resolution](#12-npm-install-dependency-resolution)
   - [1.3 ENCRYPTION_KEY setup](#13-encryption_key-setup)
   - [1.4 opencode auth.json location](#14-opencode-authjson-location)
   - [1.5 Docker Compose as alternative](#15-docker-compose-as-alternative)
2. [One-Click Setup Script](#one-click-setup-script)
3. [Troubleshooting](#troubleshooting)

---

## Pitfalls

### 1.1 Node.js installation

**Problem:** Homebrew on macOS 14+ tries to build Node from source (cmake, openssl, python from scratch) — takes 30-70 minutes, often fails due to network/CPU.

**Fix:** Use prebuilt binary
```bash
curl -fsSL https://nodejs.org/dist/v22.17.0/node-v22.17.0-darwin-arm64.tar.gz | tar xzv -C /tmp
cp -R /tmp/node-v22.17.0-darwin-arm64 \
  /Users/$(whoami)/.local/share/nodejs/
ln -sf /Users/$(whoami)/.local/share/nodejs/bin/node \
  /Users/$(whoami)/.local/bin/node
ln -sf /Users/$(whoami)/.local/share/nodejs/bin/npm \
  /Users/$(whoami)/.local/bin/npm
```

Alternatively, use `nvm`:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
nvm install 22
```

---

### 1.2 npm install / dependency resolution

**Problem:** Some systems have `npm warn deprecated` / vulnerability warnings. Server may fail to start if native modules (better-sqlite3, esbuild) fail to compile.

**Fix:**
```bash
npm install
# If native module fails, check:
uname -a
# On macOS 14+, install build tools:
xcode-select --install
brew install cmake
```

**NPM cache issue:** If `npm install` silently fails:
```bash
npm cache clean --force
rm -rf node_modules
npm install
```

---

### 1.3 ENCRYPTION_KEY setup

**Problem:** Forgetting to set `ENCRYPTION_KEY` results in:
- "Missing key from .env" warning
- No database encryption
- Keys stored in plaintext (only in dev)
- Docker: container can't read DB after restart

**Fix:** Generate a 32-byte hex key and save in `.env`:
```bash
KEY="$(node -e 'console.log(require("crypto").randomBytes(32).toString("hex"))')"
printf "ENCRYPTION_KEY=%s\nPORT=3001\n" "$KEY" > .env
```

**HARDLY EVER set in Git:** Ensure `.env` is ignored (`git check-ignore .env` should return `.env`).

**Docker:** Never set `ENCRYPTION_KEY` in docker-compose.env; use `.env` file only.

---

### 1.4 opencode auth.json location

**Problem:** After installing opencode, the CLI launcher redirects data to `~/.local/share/opencode-cli` instead of `~/.local/share/opencode`. The wrong auth.json path keeps the unified key out of reach.

**Wrong path (don't use):**
- `~/.config/opencode/opencode.json` — OK, this is config
- `~/.local/share/opencode/auth.json` — **WRONG**, the key isn't read here

**Correct auth.json location:**
- `~/.local/share/opencode-cli/opencode/auth.json` — **KEYS HERE**

**Add the key:**
```bash
cat > ~/.local/share/opencode-cli/opencode/auth.json <<EOF
{
  "freellmapi": {
    "type": "api",
    "key": "<your-unified-key>"
  }
}
EOF
```

To find the unified key, start the server and read from dashboard:
```bash
curl http://127.0.0.1:3001/api/settings/api-key \
  -H "Authorization: Bearer <dash-session-token>"
```

**Restart opencode** or reselect the `freellmapi/auto` model after changing auth.json.

---

### 1.5 Docker Compose as alternative

**Problem:** If you spend 30+ minutes on Node install + npm, you're missing the obvious "one-click" path that follows a Docker container.

**Solution:** Always keep Docker Compose as the primary install method. It handles:
- Server + dashboard as one container
- SQLite persistence via named volume
- Automatic logging
- Zero Node/npm/installation on target machine (only Docker Desktop needed)
- UUID-generated ENCRYPTION_KEY (usually doesn't need manual input)

**Docker Compose command:**
```bash
git clone https://github.com/your-username/freellmapi.git && cd freellmapi
ENCRYPTION_KEY="$(openssl rand -hex 32)"
printf "ENCRYPTION_KEY=%s\nPORT=3001\n" "$ENCRYPTION_KEY" > .env
docker compose up -d
```

**Troubleshooting:** If `docker compose up` fails:
- macOS: ensure Docker Desktop is running (`docker --version`)
- _All: ensure `usermod -a -G docker $(whoami)`_ or check firewall

---

## One-Click Setup Script

> Place `docs/en/local-dev-setup.sh` (and `docs/zh-cn/local-dev-setup.sh`) in your repo for a self-contained bootstrap.

```bash
#!/bin/bash
# local-dev-setup.sh
# https://github.com/your-username/freellmapi

set -euo pipefail

echo "=== FreeLLMAPI Local Dev Setup ==="

# Node.js installation (prebuilt)
if ! command -v node &> /dev/null; then
  echo "Installing Node 22..."
  curl -fsSL https://nodejs.org/dist/v22.17.0/node-v22.17.0-darwin-arm64.tar.gz | tar xzv -C /tmp
  ln -sf /tmp/node-v22.17.0-darwin-arm64/bin/node "$HOME/.local/share/nodejs/bin/node"
  ln -sf /tmp/node-v22.17.0-darwin-arm64/bin/npm "$HOME/.local/share/nodejs/bin/npm"
else
  echo "Node already installed: $(node --version)"
fi

# Dependencies
echo "Installing npm packages..."
npm install

# Generate .env
echo "Generating ENCRYPTION_KEY..."
KEY="$(node -e 'console.log(require("crypto").randomBytes(32).toString("hex"))')"
printf "ENCRYPTION_KEY=%s\nPORT=3001\n" "$KEY" > .env

# Start server
echo "Starting server..."
npm run dev
```

Add instructions to README:
```markdown
## Local Setup (Quick)

```bash
./docs/en/local-dev-setup.sh && npm run dev
```
Then open http://localhost:5173, click "Keys", and you're done.
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|--------|-------------|-----|
| `Invalid API key` from opencode | auth.json in wrong location (`~/.local/share/opencode/auth.json` vs `~/.local/share/opencode-cli/opencode/auth.json`) | Add key to correct location; restart opencode |
| Server starts but no connection | Port 3001 already used (another dev server) | `lsof -i :3001` → kill or use `PORT=3002` |
| `npm install` fails with native module error | Missing cmake / python | `brew install cmake` + `python@3.11` |
| Dashboard can't reach API | Browser firewall or CORS | Temporarily firewall off `localhost:3001` |
| `ENCRYPTION_KEY` missing in docker | Container killed before .env mounted | Use `docker compose up` (not `docker run`) |
| Docker logs say `exit 1` | Host network permissions / Apple Silicon | Install Docker Desktop with latest CLI |

---

## See Also

- [Docker Compose install docs](https://github.com/tashfeenahmed/freellmapi/blob/main/docs/en/install/01-install.md)
- [OpenCode setup (cli + auth)](https://github.com/tashfeenahmed/freellmapi/tree/main/cli/src/tools.ts#L280-L300)
- [Provider keys guide](https://github.com/tashfeenahmed/freellmapi/tree/main/server/src/providers)

---

## Contributors

Thanks to the [freellmapi](https://github.com/tashfeenahmed/freellmapi) maintainers for the OpenCode-compatible gateway.
