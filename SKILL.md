---
name: jarvis-memory
description: Store and retrieve agent memory using local Jarvis Memory API. Semantic search, confidence scoring, memory decay, and full CRUD for persistent agent memory.
user-invocable: true
metadata: {"openclaw": {"emoji": "🧠"}}
---

# 🧠 Jarvis Memory

Persistent memory storage with semantic search, confidence scoring, and memory decay for AI agents. Save text as seeds, search semantically, manage memory quality, and persist agent context between sessions — entirely locally.

## ✨ Features

- 🔍 **Semantic Search** — Find memories by meaning (GTE-Small, 384 dimensions, pgvector HNSW)
- 🎯 **Confidence Scoring** — Each seed has a weight (0.0–1.0) that influences search ranking
- 📉 **Memory Decay** — Old, low-confidence seeds automatically lose relevance
- ✏️ **Full CRUD** — Create, update, and delete seeds via REST API
- 🔄 **Auto-Recall** — Queries relevant memories before each AI turn and injects as context
- 💾 **Auto-Capture** — Saves conversations after each AI turn
- 🖥️ **Admin Panel** — Dark-themed dashboard with edit/delete/confidence controls
- 🔒 **100% Local** — No API keys, no external services, complete privacy

## Prerequisites

The API runs as a Docker container. Ensure it's running:

```bash
cd /home/jarvis/jarvis-memory
docker compose up -d
```

The API is available at `http://localhost:8080`. No API keys or authentication required.

## Testing

```bash
./scripts/jarvis-memory.sh test
```

Or open the admin dashboard: **http://localhost:8080/admin**

## Hooks (Auto-Capture & Auto-Recall)

- `hooks/pre-tool-use.sh` — 🔍 **Auto-Recall**: Queries memories before AI turn, injects relevant context
- `hooks/post-tool-use.sh` — 💾 **Auto-Capture**: Saves conversation after AI turn

### Configuration

Both features are **enabled by default**. To disable:

```bash
export JARVIS_AUTO_RECALL=false
export JARVIS_AUTO_CAPTURE=false
```

## Scripts

Use the CLI tool in the `scripts/` directory:

```bash
./scripts/jarvis-memory.sh <command> [args]
```

## Common Operations

### 💾 Save a Memory
```bash
./scripts/jarvis-memory.sh save "Content to remember" "Title" [type]
```

### 🔍 Semantic Search
```bash
./scripts/jarvis-memory.sh search "query text" [limit] [threshold]
```

### ✏️ Update a Seed
```bash
curl -X PUT http://localhost:8080/seeds/<UUID> \
  -H "Content-Type: application/json" \
  -d '{"content":"corrected info","title":"Fixed Title","type":"semantic"}'
```

### 🗑️ Delete a Seed
```bash
curl -X DELETE http://localhost:8080/seeds/<UUID>
```

### ⚖️ Set Confidence
```bash
curl -X POST http://localhost:8080/seeds/<UUID>/confidence \
  -H "Content-Type: application/json" \
  -d '{"confidence": 0.5}'
```

### 🤖 Create Agent Context
```bash
./scripts/jarvis-memory.sh context-create "agent-id" "episodic" '{"key":"value"}' "Summary"
```

### 📋 List Agent Contexts
```bash
./scripts/jarvis-memory.sh context-list "agent-id"
```

### 🔎 Get Specific Context
```bash
./scripts/jarvis-memory.sh context-get <UUID>
```

## 🎯 Confidence & Decay

Each seed has a **confidence** value (default `1.0`). Search results are weighted:

```
weighted_similarity = cosine_similarity × confidence
```

**Automatic Decay:** On each server restart, seeds older than 90 days with confidence < 0.3 are reduced by 10%. Seeds are never fully erased automatically (floor: 0.01).

**Last Accessed:** Every search hit updates `last_accessed`, enabling usage-based decay strategies.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/seeds` | 💾 Save text (multipart: `content`, `title`, `type`) |
| `POST` | `/seeds/query` | 🔍 Semantic search (JSON: `query`, `limit`, `threshold`) |
| `PUT` | `/seeds/:id` | ✏️ Update seed (JSON: `content`, `title`, `type`) |
| `DELETE` | `/seeds/:id` | 🗑️ Delete a seed |
| `POST` | `/seeds/:id/confidence` | ⚖️ Set confidence (JSON: `confidence`) |
| `POST` | `/agent-contexts` | 📝 Create agent context |
| `GET` | `/agent-contexts` | 📋 List contexts (`?agentId=` filter) |
| `GET` | `/agent-contexts/:id` | 🔎 Get specific context |
| `GET` | `/admin` | 🖥️ Admin dashboard |

**Base URL:** `http://localhost:8080`
**Auth:** None required.

**Memory types:** `episodic`, `semantic`, `procedural`, `working`
**Seed content types:** `text`, `markdown`, `json`, `csv`, `auto_capture`
