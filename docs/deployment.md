# Hermes Agent — Cloud Deployment on Render with WeChat

## Overview

This document describes the full workflow for deploying Hermes Agent to Render (cloud) with WeChat (Weixin) integration, using Docker and a Render Persistent Disk for data persistence.

---

## Key Technical Discoveries

Before building anything, the Hermes Agent source code was analyzed. Three findings shaped every decision:

### 1. WeChat uses long-polling, not webhooks
The WeChat (Weixin) adapter (`gateway/platforms/weixin.py`) polls Tencent's iLink API with a 35-second timeout — it makes **outbound** HTTP requests. This means:
- No public URL is needed for WeChat
- Hermes can run as a **Background Worker** (no inbound HTTP required)
- Any server with internet access works — no complex ingress configuration

### 2. Hermes uses SQLite only
Hermes stores all state in `HERMES_HOME/state.db` (SQLite with FTS5). There is no PostgreSQL or external database support. For cloud deployment this means:
- A **Render Persistent Disk** mounted at `HERMES_HOME` is sufficient
- No Neon or external database is needed

### 3. HERMES_HOME controls everything
The environment variable `HERMES_HOME` (default: `~/.hermes`) points to the entire data directory: SQLite database, WeChat credentials, config, skills, sessions. Pointing it to a persistent volume is all that's needed for stateful cloud deployment.

---

## Architecture

```
WeChat User
    │
    │  (WeChat app)
    ▼
Tencent iLink API  ◄──── long-poll (outbound) ────  Hermes Gateway
                                                      (Render Worker)
                                                            │
                                                     /opt/data (Persistent Disk)
                                                      ├── state.db
                                                      ├── config.yaml
                                                      └── weixin/accounts/
                                                                └── 6bf2192788fb@im.bot.json
```

---

## Files Created

### `Dockerfile`
Builds the container image. Installs `hermes-agent` via `uv`, sets `HERMES_HOME=/opt/data`, and runs the entrypoint script.

```dockerfile
FROM python:3.12-slim
RUN pip install --no-cache-dir uv
WORKDIR /app
COPY pyproject.toml .
RUN uv pip install --system "hermes-agent>=0.13.0"
ENV HERMES_HOME=/opt/data
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

### `scripts/entrypoint.sh`
Runs on every container start. Seeds `config.yaml` and the WeChat account credentials from environment variables — but **only on first boot** (skips if files already exist on the Persistent Disk). This avoids overwriting live session data on restarts.

Logic:
1. If `$HERMES_HOME/config.yaml` does not exist → write it from `MODEL_*` env vars
2. If `$HERMES_HOME/weixin/accounts/$WEIXIN_ACCOUNT_ID.json` does not exist → write it from `WEIXIN_*` env vars
3. `exec hermes gateway start`

### `render.yaml`
Declares the Render infrastructure as code:
- Service type: **Background Worker**
- Runtime: Docker
- Persistent Disk: 5 GB mounted at `/opt/data`
- All environment variable keys declared (values set as secrets in the Render dashboard)

### `pyproject.toml`
Updated to declare `hermes-agent>=0.13.0` as a dependency so the package is installed during the Docker build.

---

## Environment Variables

All variables are set as secrets in the Render dashboard (never committed to the repo).

### Model / LLM Provider

| Variable | Description |
|---|---|
| `MODEL_API_KEY` | API key for the LLM provider |
| `MODEL_BASE_URL` | Provider base URL (e.g. `https://api.openai.com/v1`) |
| `MODEL_NAME` | Model name (e.g. `gpt-5.4-mini`) |

### WeChat (Weixin)

| Variable | Description | Example Value |
|---|---|---|
| `WEIXIN_ACCOUNT_ID` | Filename stem of the account credentials file | `6bf2192788fb@im.bot` |
| `WEIXIN_TOKEN` | iLink bot authentication token | `6bf2192788fb@im.bot:060000...` |
| `WEIXIN_USER_ID` | Paired WeChat user ID (used by entrypoint.sh) | `o9cq806Q...@im.wechat` |
| `WEIXIN_BASE_URL` | Tencent iLink API base URL | `https://ilinkai.weixin.qq.com` |
| `WEIXIN_CDN_BASE_URL` | CDN for media (images, files) | `https://novac2c.cdn.weixin.qq.com/c2c` |
| `WEIXIN_DM_POLICY` | Who can DM the bot | `pairing` |
| `WEIXIN_ALLOW_ALL_USERS` | Open to all WeChat users | `false` |
| `WEIXIN_HOME_CHANNEL` | Default reply target | `o9cq806Q...@im.wechat` |

> `WEIXIN_ACCOUNT_ID`, `WEIXIN_TOKEN`, `WEIXIN_BASE_URL` come from `~/.hermes/weixin/accounts/<id>.json` on the local machine.
> `WEIXIN_HOME_CHANNEL` comes from `~/.hermes/channel_directory.json` → `platforms.weixin[0].id`.

---

## How to Get Local Credentials

Run these commands on the local machine where Hermes is already configured:

```bash
# Model config
grep -E "api_key|base_url|default" ~/.hermes/config.yaml | head -5

# WeChat account ID (filename stem)
ls ~/.hermes/weixin/accounts/

# WeChat token, base_url, user_id
cat ~/.hermes/weixin/accounts/6bf2192788fb@im.bot.json

# WeChat home channel
python3 -c "import json; d=json.load(open(open.__module__.__class__.__mro__[-1].__subclasses__()[-1].__init__.__globals__['__builtins__']['open']('dummy'))); ..." 
# simpler:
cat ~/.hermes/channel_directory.json | python3 -m json.tool | grep -A5 '"weixin"'
```

---

## Render Deployment Steps

1. Push the `hermes/backend` repo to GitHub
2. Render Dashboard → **New+ → Background Worker**
3. Connect GitHub repo, select branch `main`
4. Runtime: **Docker**, Root Directory: *(leave empty)*
5. Instance: **Starter ($7/month)** minimum — Free plan does not support Persistent Disk
6. Add all environment variables (see table above) as secret env vars
7. After creation, go to **Disks** → Add disk: mount path `/opt/data`, size 5 GB
8. Trigger a deploy

---

## Verifying the Deployment

Watch the Render logs after deploy. Expected output:

```
[entrypoint] Seeded config.yaml (model: gpt-5.4-mini)
[entrypoint] Seeded WeChat credentials for 6bf2192788fb@im.bot
[gateway] Starting platform adapters...
[weixin] Polling for messages...
```

Then send a WeChat message to the configured account — Hermes should respond.

**Persistence check:** Restart the Render service. Credentials already exist on the Persistent Disk so the entrypoint skips seeding and resumes the session without re-authentication.

---

## Why Not Neon / PostgreSQL?

Hermes has no native PostgreSQL support — all state is SQLite. Render Persistent Disk gives SQLite the durability it needs in a cloud environment at much lower complexity. Neon would only be useful if building a separate API layer on top of Hermes (e.g. a custom FastAPI service for frontend queries or analytics).
