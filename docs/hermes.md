# Hermes Agent

**Source:** https://github.com/nousresearch/hermes-agent  
**By:** Nous Research

---

## What Hermes Agent Is (and Is Not)

> **Hermes Agent is NOT a language model.** Do not confuse it with the Hermes series of fine-tuned LLMs (also by Nous Research). Those are models. This is an agent framework — a system that uses models to act autonomously.

Hermes Agent is a self-improving, autonomous AI agent framework built in Python. It is designed to run as a persistent assistant that learns from experience, maintains memory across sessions, and operates across multiple platforms.

---

## Core Concepts

### Self-Improvement via Skill Creation
The agent runs a closed feedback loop: it creates skills from experience and refines them during use. Over time it builds a personal library of reusable capabilities rather than re-deriving solutions from scratch.

### Persistent Memory
Hermes maintains user models and session history across conversations. It uses FTS5 full-text search and LLM summarization to store and retrieve context efficiently. Memory persists across restarts and platforms.

### Multi-Platform
Users can interact via:
- Terminal UI
- Telegram
- Discord
- Slack
- WhatsApp
- Signal

Conversation continuity is maintained across all platforms.

### Model Agnosticism
The agent is not tied to any one model. Supported providers include:
- OpenRouter
- OpenAI
- Anthropic
- Others via standard APIs

You can swap models without changing application code.

### Flexible Deployment
Designed to run anywhere from a $5 VPS to a GPU cluster to serverless infrastructure. Supported backends:
- Docker
- SSH
- Modal
- Daytona
- And more (7 total terminal backend options)

---

## Architecture

The agent operates through a continuous loop:

```
Conversation → Tool Execution → Memory Persistence → Skill Creation → User Modeling → (repeat)
```

Key components:
- **Skill engine** — auto-generates and improves skills from past interactions
- **Memory store** — FTS5-indexed session search + LLM summarization
- **Subagent spawning** — parallel subagents for concurrent task execution
- **Cron scheduler** — scheduled autonomous tasks
- **MCP integration** — compatible with Model Context Protocol (MCP) and the agentskills.io open standard

---

## Tech Stack

| Layer | Technology |
|---|---|
| Primary language | Python (~88%) |
| Frontend/UI components | TypeScript (~9%) |
| Memory/search | SQLite FTS5 |
| Protocol | MCP (Model Context Protocol) |
| Skills standard | agentskills.io |

---

## Key Differentiators vs. a Typical Chatbot

| Feature | Typical Chatbot | Hermes Agent |
|---|---|---|
| Memory | Per-session only | Persistent across sessions |
| Learning | None | Builds skills from experience |
| Deployment | Hosted service | Self-hosted, any infra |
| Model | Fixed | Swappable |
| Platforms | One | Terminal + 5 messaging apps |
| Autonomy | Reactive | Proactive (cron, subagents) |
