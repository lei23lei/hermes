FROM python:3.12-slim

RUN pip install --no-cache-dir uv

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pyproject.toml .
RUN uv pip install --system "hermes-agent @ git+https://github.com/NousResearch/hermes-agent.git@v2026.5.7"

ENV HERMES_HOME=/opt/data

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
