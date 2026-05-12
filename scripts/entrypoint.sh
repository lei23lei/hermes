#!/bin/bash
set -e

HERMES_HOME=${HERMES_HOME:-/opt/data}
mkdir -p "$HERMES_HOME"

# Seed config.yaml on first boot (skip if already exists from persistent disk)
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
  python3 - <<'PYEOF'
import os

hermes_home = os.environ["HERMES_HOME"]
model_name = os.environ.get("MODEL_NAME", "gpt-4o-mini")
base_url = os.environ.get("MODEL_BASE_URL", "https://api.openai.com/v1")
api_key = os.environ["MODEL_API_KEY"]

config = f"""model:
  default: {model_name}
  provider: custom
  base_url: {base_url}
  api_key: {api_key}
agent:
  max_turns: 90
  gateway_timeout: 1800
  restart_drain_timeout: 180
  api_max_retries: 3
  tool_use_enforcement: auto
  gateway_timeout_warning: 900
  gateway_notify_interval: 180
  gateway_auto_continue_freshness: 3600
"""

with open(f"{hermes_home}/config.yaml", "w") as f:
    f.write(config)

print(f"[entrypoint] Seeded config.yaml (model: {model_name})")
PYEOF
fi

# Seed WeChat (Weixin) account credentials on first boot
# WEIXIN_ACCOUNT_ID = the account filename stem, e.g. 6bf2192788fb@im.bot
# WEIXIN_TOKEN      = the iLink bot token
# WEIXIN_USER_ID    = the paired WeChat user ID (e.g. o9cq806Q...@im.wechat)
# WEIXIN_BASE_URL   = optional, defaults to https://ilinkai.weixin.qq.com
if [ -n "$WEIXIN_ACCOUNT_ID" ] && [ -n "$WEIXIN_TOKEN" ]; then
  WEIXIN_DIR="$HERMES_HOME/weixin/accounts"
  mkdir -p "$WEIXIN_DIR"
  ACCOUNT_FILE="$WEIXIN_DIR/${WEIXIN_ACCOUNT_ID}.json"

  if [ ! -f "$ACCOUNT_FILE" ]; then
    python3 - <<'PYEOF'
import json, os

account_id = os.environ["WEIXIN_ACCOUNT_ID"]
hermes_home = os.environ["HERMES_HOME"]

data = {
    "token": os.environ["WEIXIN_TOKEN"],
    "base_url": os.environ.get("WEIXIN_BASE_URL", "https://ilinkai.weixin.qq.com"),
    "user_id": os.environ.get("WEIXIN_USER_ID", ""),
}

path = f"{hermes_home}/weixin/accounts/{account_id}.json"
with open(path, "w") as f:
    json.dump(data, f, indent=2)

print(f"[entrypoint] Seeded WeChat credentials for {account_id}")
PYEOF
  fi
fi

exec hermes gateway run
